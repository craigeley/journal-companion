//
//  AudioRecorderViewModel.swift
//  JournalCompanion
//
//  Manages audio recording state and real-time transcription
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import CoreMedia

@MainActor
class AudioRecorderViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var volatileTranscription = ""
    @Published var finalizedTranscription = ""
    @Published var errorMessage: String?
    @Published var isTranscriptionAvailable = false
    @Published var permissionsDenied = false

    // MARK: - Services

    private let recordingService: AudioRecordingService
    private let transcriptionService: SpeechTranscriptionService
    private let vaultURL: URL

    // Recording state
    private var recordingURL: URL?
    private var durationTimer: Timer?
    private var audioFormat: AudioFormat

    // MARK: - Initialization

    init(vaultURL: URL, audioFormat: AudioFormat = .aac) {
        self.vaultURL = vaultURL
        self.audioFormat = audioFormat
        self.recordingService = AudioRecordingService()
        self.transcriptionService = SpeechTranscriptionService()

        Task {
            isTranscriptionAvailable = await transcriptionService.isAvailable()
        }
    }

    // MARK: - Computed Properties

    /// Combined transcription with volatile (gray) and finalized (black) text
    var displayedTranscription: AttributedString {
        var result = AttributedString()

        // Add finalized text (black)
        if !finalizedTranscription.isEmpty {
            var finalPart = AttributedString(finalizedTranscription)
            finalPart.foregroundColor = .primary
            result.append(finalPart)

            if !volatileTranscription.isEmpty {
                result.append(AttributedString(" "))
            }
        }

        // Add volatile text (gray)
        if !volatileTranscription.isEmpty {
            var volatilePart = AttributedString(volatileTranscription)
            volatilePart.foregroundColor = .secondary
            result.append(volatilePart)
        }

        return result
    }

    var formattedDuration: String {
        let minutes = Int(currentDuration) / 60
        let seconds = Int(currentDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Recording Control

    /// Get the best supported locale for transcription
    private func getBestSupportedLocale() async -> Locale {
        // Use Apple's built-in method to find equivalent locale
        if let equivalentLocale = await SpeechTranscriptionService.getSupportedLocale(equivalentTo: .current) {
            print("✓ Using locale: \(equivalentLocale.identifier) (equivalent to \(Locale.current.identifier))")
            return equivalentLocale
        }

        // Fallback to first available or en_US
        let supportedLocales = await SpeechTranscriptionService.getSupportedLocales()
        let fallback = supportedLocales.first ?? Locale(identifier: "en_US")
        print("⚠️ Using fallback locale: \(fallback.identifier)")
        return fallback
    }

    func startRecording() async {
        do {
            // Check permissions
            let micPermission = await AudioRecordingService.checkPermission()
            let speechPermission = await SpeechTranscriptionService.checkPermission()

            guard micPermission else {
                errorMessage = "Microphone access is required to record audio."
                permissionsDenied = true
                return
            }

            if isTranscriptionAvailable && !speechPermission {
                errorMessage = "Speech recognition access is required for transcription."
                permissionsDenied = true
                return
            }

            // Start recording
            recordingURL = try await recordingService.startRecording(format: audioFormat)
            isRecording = true
            errorMessage = nil

            // Start duration timer
            startDurationTimer()

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
        }
    }

    func pauseRecording() async {
        guard isRecording else { return }

        do {
            try await recordingService.pauseRecording()
            isPaused = true
            stopDurationTimer()
        } catch {
            errorMessage = "Failed to pause recording: \(error.localizedDescription)"
        }
    }

    func resumeRecording() async {
        guard isPaused else { return }

        do {
            try await recordingService.resumeRecording()
            isPaused = false
            startDurationTimer()
        } catch {
            errorMessage = "Failed to resume recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() async -> (url: URL, duration: TimeInterval, transcription: String, timeRanges: [TimeRange])? {
        guard isRecording else { return nil }

        do {
            // Stop recording
            let (url, duration) = try await recordingService.stopRecording()

            // Clean up
            stopDurationTimer()
            isRecording = false
            isPaused = false

            // Transcribe the recorded file if transcription is available
            var finalTranscription = ""
            var timeRanges: [TimeRange] = []
            if isTranscriptionAvailable {
                let locale = await getBestSupportedLocale()
                do {
                    let result = try await transcriptionService.transcribeFile(url: url, locale: locale)
                    finalTranscription = result.text
                    timeRanges = result.timeRanges
                    print("✓ Transcribed \(result.text.count) characters with \(timeRanges.count) time ranges")
                } catch {
                    print("⚠️ Transcription failed: \(error.localizedDescription)")
                    // Continue without transcription
                }
            }

            // Reset for next recording
            reset()

            return (url, duration, finalTranscription, timeRanges)

        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            return nil
        }
    }

    func cancelRecording() async {
        if isRecording {
            _ = await stopRecording()

            // Delete temp file
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        reset()
    }

    // MARK: - Private Helpers

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentDuration = await self.recordingService.currentDuration()
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func reset() {
        currentDuration = 0
        volatileTranscription = ""
        finalizedTranscription = ""
        recordingURL = nil
        errorMessage = nil
    }
}
