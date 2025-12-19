//
//  SpeechTranscriptionService.swift
//  JournalCompanion
//
//  Real-time speech transcription using iOS 26 SpeechAnalyzer API
//

import Foundation
import Speech
@preconcurrency import AVFoundation
@preconcurrency import AVFAudio
import CoreMedia

// MARK: - Speech Transcription Service

actor SpeechTranscriptionService {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<Void, Never>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?

    // Collected results
    private var finalizedText: String = ""
    private var timeRanges: [TimeRange] = []

    // MARK: - Public Interface

    /// Start real-time transcription with callbacks for volatile and finalized results
    func startTranscription(
        locale: Locale = .current,
        onVolatile: @escaping @Sendable (String) -> Void,
        onFinalized: @escaping @Sendable (String, CMTimeRange?) -> Void
    ) async throws {
        // Check if locale is supported
        guard await SpeechTranscriber.supportedLocales.contains(locale) else {
            throw TranscriptionError.localeNotSupported
        }

        // Check if model is installed
        if !(await SpeechTranscriber.installedLocales.contains(locale)) {
            try await downloadModel(for: locale)
        }

        // Configure transcriber
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let transcriber else {
            throw TranscriptionError.initializationFailed
        }

        // Create analyzer
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // Get optimal audio format
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        // Start processing results
        recognizerTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)

                    if result.isFinal {
                        // Finalized result - high quality
                        await MainActor.run {
                            onFinalized(text, result.text.audioTimeRange)
                        }

                        // Store time range for highlighted playback
                        if let timeRange = result.text.audioTimeRange {
                            let start = CMTimeGetSeconds(timeRange.start)
                            let end = start + CMTimeGetSeconds(timeRange.duration)

                            timeRanges.append(TimeRange(
                                text: text,
                                start: start,
                                end: end
                            ))
                        }

                        finalizedText += text + " "
                    } else {
                        // Volatile result - immediate but less accurate
                        await MainActor.run {
                            onVolatile(text)
                        }
                    }
                }
            } catch {
                print("❌ Speech recognition error: \(error)")
            }
        }

        print("✓ Speech transcription started for locale: \(locale.identifier)")
    }

    /// Process audio buffer for transcription
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async throws {
        guard let _ = analyzer, let analyzerFormat else {
            throw TranscriptionError.notInitialized
        }

        // Convert buffer to analyzer format if needed
        let convertedBuffer = try convertBufferIfNeeded(buffer, to: analyzerFormat)

        // Create analyzer input
        let input = AnalyzerInput(buffer: convertedBuffer)

        // Send to analyzer
        inputBuilder?.yield(input)
    }

    /// Stop transcription and return results
    func stopTranscription() async -> TranscriptionResult {
        recognizerTask?.cancel()
        recognizerTask = nil

        let result = TranscriptionResult(
            text: finalizedText.trimmingCharacters(in: .whitespacesAndNewlines),
            timeRanges: timeRanges,
            isFinal: true
        )

        // Clean up
        transcriber = nil
        analyzer = nil
        inputBuilder = nil
        analyzerFormat = nil
        finalizedText = ""
        timeRanges = []

        print("✓ Speech transcription stopped. Transcribed: \(result.text.prefix(50))...")
        return result
    }

    /// Transcribe an audio file (post-recording transcription)
    func transcribeFile(url: URL, locale: Locale = .current) async throws -> TranscriptionResult {
        // Check if locale is supported
        guard await SpeechTranscriber.supportedLocales.contains(locale) else {
            throw TranscriptionError.localeNotSupported
        }

        // Check if model is installed
        if !(await SpeechTranscriber.installedLocales.contains(locale)) {
            try await downloadModel(for: locale)
        }

        // Configure transcriber for file transcription
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .transcription
        )

        // Process file
        async let transcriptionFuture: (String, [TimeRange]) = {
            var text = ""
            var ranges: [TimeRange] = []
            for try await result in transcriber.results {
                let resultText = String(result.text.characters)
                text += resultText

                if result.isFinal, let timeRange = result.text.audioTimeRange {
                    let start = CMTimeGetSeconds(timeRange.start)
                    let end = start + CMTimeGetSeconds(timeRange.duration)

                    ranges.append(TimeRange(
                        text: resultText,
                        start: start,
                        end: end
                    ))
                }
            }
            return (text, ranges)
        }()

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let (finalText, ranges) = try await transcriptionFuture

        return TranscriptionResult(
            text: finalText,
            timeRanges: ranges,
            isFinal: true
        )
    }

    /// Check if speech recognition is available
    func isAvailable() async -> Bool {
        await !SpeechTranscriber.supportedLocales.isEmpty
    }

    // MARK: - Permissions

    /// Check speech recognition permission status
    static func checkPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Request speech recognition permission
    static func requestPermission() async -> Bool {
        return await checkPermission()
    }

    // MARK: - Private Helpers

    private func downloadModel(for locale: Locale) async throws {
        guard let transcriber else {
            throw TranscriptionError.initializationFailed
        }

        print("📥 Downloading speech model for \(locale.identifier)...")

        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await downloader.downloadAndInstall()
            print("✓ Speech model downloaded successfully")
        }
    }

    private func convertBufferIfNeeded(
        _ buffer: AVAudioPCMBuffer,
        to format: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        // If formats match, return original
        if buffer.format == format {
            return buffer
        }

        // Convert buffer to target format
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            throw TranscriptionError.audioFormatConversionFailed
        }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw TranscriptionError.audioFormatConversionFailed
        }

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            throw error
        }

        return convertedBuffer
    }
}

// MARK: - Transcription Result

struct TranscriptionResult: Sendable {
    let text: String
    let timeRanges: [TimeRange]
    let isFinal: Bool
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case notInitialized
    case localeNotSupported
    case modelNotInstalled
    case initializationFailed
    case audioFormatConversionFailed
    case speechRecognitionPermissionDenied
    case speechRecognitionUnavailable

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Transcription service not initialized."
        case .localeNotSupported:
            return "The selected language is not supported for transcription."
        case .modelNotInstalled:
            return "Speech recognition model not installed. Downloading..."
        case .initializationFailed:
            return "Failed to initialize speech transcription."
        case .audioFormatConversionFailed:
            return "Failed to convert audio format for transcription."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition permission denied. Enable in Settings > Privacy > Speech Recognition."
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device."
        }
    }
}
