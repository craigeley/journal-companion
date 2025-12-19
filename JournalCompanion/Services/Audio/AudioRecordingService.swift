//
//  AudioRecordingService.swift
//  JournalCompanion
//
//  Actor-based audio recording service using AVAudioEngine
//

import Foundation
import AVFoundation

// MARK: - Audio Recording Service

actor AudioRecordingService {
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    private var recordingStartTime: Date?
    private var isPaused = false
    private var currentFormat: AudioFormat = .aac

    // MARK: - Public Interface

    /// Start recording audio to a temporary file
    /// Returns: (tempURL, recordingDeviceName, sampleRate, bitDepth)
    func startRecording(format: AudioFormat) async throws -> (url: URL, deviceName: String, sampleRate: Int, bitDepth: Int?) {
        // Configure audio session
        try await configureAudioSession()

        // Create temporary file URL
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(format.fileExtension)

        currentFormat = format

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file for recording
        let fileSettings = createAudioSettings(for: format, recordingFormat: recordingFormat)
        audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: fileSettings
        )

        // Create format for the output file
        guard let fileFormat = AVAudioFormat(settings: fileSettings) else {
            throw AudioRecordingError.fileCreationFailed
        }

        // Create converter only if conversion is actually needed
        let needsConversion = recordingFormat.sampleRate != fileFormat.sampleRate ||
                              recordingFormat.channelCount != fileFormat.channelCount ||
                              recordingFormat.commonFormat != fileFormat.commonFormat

        if needsConversion {
            audioConverter = AVAudioConverter(from: recordingFormat, to: fileFormat)
            print("⚙️ Using audio converter: \(recordingFormat.sampleRate)Hz → \(fileFormat.sampleRate)Hz")
        } else {
            audioConverter = nil
            print("✓ No conversion needed, formats match: \(recordingFormat.sampleRate)Hz")
        }

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task {
                await self.writeBuffer(buffer)
            }
        }

        // Start engine
        try audioEngine.start()
        recordingStartTime = Date()
        isPaused = false

        // Get recording device name
        let deviceName = getRecordingDeviceName()

        // Get sample rate from recording format
        let sampleRate = Int(recordingFormat.sampleRate)

        // Get bit depth from format settings (only for WAV)
        let bitDepth = format.bitDepth

        print("✓ Started recording to: \(tempURL.lastPathComponent) using \(deviceName) at \(sampleRate)Hz")
        return (tempURL, deviceName, sampleRate, bitDepth)
    }

    /// Stop recording and return the file URL and duration
    func stopRecording() async throws -> (url: URL, duration: TimeInterval) {
        guard let file = audioFile,
              let startTime = recordingStartTime else {
            throw AudioRecordingError.notRecording
        }

        // Stop engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        let duration = Date().timeIntervalSince(startTime)
        let url = file.url

        // Clean up
        audioFile = nil
        audioConverter = nil
        recordingStartTime = nil
        isPaused = false

        print("✓ Stopped recording. Duration: \(String(format: "%.1f", duration))s")
        return (url, duration)
    }

    /// Pause recording
    func pauseRecording() async throws {
        guard audioEngine.isRunning else {
            throw AudioRecordingError.notRecording
        }

        audioEngine.pause()
        isPaused = true
        print("⏸ Recording paused")
    }

    /// Resume recording
    func resumeRecording() async throws {
        guard isPaused else {
            throw AudioRecordingError.notPaused
        }

        try audioEngine.start()
        isPaused = false
        print("▶ Recording resumed")
    }

    /// Get current recording duration
    func currentDuration() async -> TimeInterval {
        guard let startTime = recordingStartTime else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }

    /// Get current audio level (0.0 - 1.0) for waveform visualization
    func currentLevel() async -> Float {
        let inputNode = audioEngine.inputNode
        let _ = inputNode.outputFormat(forBus: 0)

        // This is a simplified level meter
        // In production, you'd want to use AVAudioEngine's built-in level metering
        return 0.5 // Placeholder - implement proper level metering
    }

    /// Check if currently recording
    func isRecording() async -> Bool {
        audioEngine.isRunning && recordingStartTime != nil
    }

    // MARK: - Private Helpers

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let file = audioFile, !isPaused else { return }

        do {
            // Convert buffer if needed
            if let converter = audioConverter {
                // Calculate output buffer size
                let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: converter.outputFormat,
                    frameCapacity: outputFrameCapacity
                ) else {
                    print("❌ Failed to create conversion buffer")
                    return
                }

                // Perform conversion
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if let error = error {
                    print("❌ Error converting audio buffer: \(error)")
                    return
                }

                try file.write(from: convertedBuffer)
            } else {
                // No conversion needed
                try file.write(from: buffer)
            }
        } catch {
            print("❌ Error writing audio buffer: \(error)")
        }
    }

    private func createAudioSettings(
        for format: AudioFormat,
        recordingFormat: AVAudioFormat
    ) -> [String: Any] {
        var settings = format.codecSettings

        // Use recording format's sample rate if not specified
        if settings[AVSampleRateKey] == nil {
            settings[AVSampleRateKey] = recordingFormat.sampleRate
        }

        return settings
    }

    private func getRecordingDeviceName() -> String {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        // Get the first input (typically the active microphone)
        if let input = currentRoute.inputs.first {
            return input.portName
        }

        return "Unknown Device"
    }
}

// MARK: - Errors

enum AudioRecordingError: LocalizedError {
    case notRecording
    case notPaused
    case audioSessionFailed
    case fileCreationFailed
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .notRecording:
            return "No active recording session."
        case .notPaused:
            return "Recording is not paused."
        case .audioSessionFailed:
            return "Failed to configure audio session."
        case .fileCreationFailed:
            return "Failed to create audio file."
        case .microphonePermissionDenied:
            return "Microphone access denied. Enable in Settings > Privacy > Microphone."
        }
    }
}

// MARK: - Permission Helpers

extension AudioRecordingService {
    /// Check microphone permission status
    static func checkPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Request microphone permission
    static func requestPermission() async -> Bool {
        return await checkPermission()
    }
}
