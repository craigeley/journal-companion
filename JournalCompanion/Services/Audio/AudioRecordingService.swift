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
        let file = try AVAudioFile(
            forWriting: tempURL,
            settings: fileSettings
        )
        audioFile = file

        // Use the file's processingFormat - this is the PCM format the file expects for input
        // (AVAudioFile handles encoding to AAC/etc internally)
        let fileProcessingFormat = file.processingFormat

        // Create converter only if conversion is actually needed
        let needsConversion = recordingFormat.sampleRate != fileProcessingFormat.sampleRate ||
                              recordingFormat.channelCount != fileProcessingFormat.channelCount ||
                              recordingFormat.commonFormat != fileProcessingFormat.commonFormat

        if needsConversion {
            audioConverter = AVAudioConverter(from: recordingFormat, to: fileProcessingFormat)
            print("⚙️ Using audio converter: \(recordingFormat.sampleRate)Hz → \(fileProcessingFormat.sampleRate)Hz")
            print("   Input format: \(recordingFormat.commonFormat.rawValue) (channels: \(recordingFormat.channelCount))")
            print("   Output format: \(fileProcessingFormat.commonFormat.rawValue) (channels: \(fileProcessingFormat.channelCount))")
        } else {
            audioConverter = nil
            print("✓ No conversion needed, formats match: \(recordingFormat.sampleRate)Hz")
        }

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Copy buffer synchronously - the original is only valid during this callback
            guard let bufferCopy = Self.copyBuffer(buffer) else { return }
            Task {
                await self.writeBuffer(bufferCopy)
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

    /// Copy an audio buffer - required because tap callback buffers are only valid during the callback
    private static func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        copy.frameLength = buffer.frameLength

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Copy based on the buffer's sample format
        if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
            for channel in 0..<channelCount {
                memcpy(dst[channel], src[channel], frameLength * MemoryLayout<Float>.size)
            }
        } else if let src = buffer.int16ChannelData, let dst = copy.int16ChannelData {
            for channel in 0..<channelCount {
                memcpy(dst[channel], src[channel], frameLength * MemoryLayout<Int16>.size)
            }
        } else if let src = buffer.int32ChannelData, let dst = copy.int32ChannelData {
            for channel in 0..<channelCount {
                memcpy(dst[channel], src[channel], frameLength * MemoryLayout<Int32>.size)
            }
        }

        return copy
    }

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])

        // Force 48kHz sample rate (native iOS rate)
        try session.setPreferredSampleRate(48000)

        try session.setActive(true)

        // Log actual sample rate achieved
        let actualSampleRate = session.sampleRate
        print("🎤 Audio session sample rate: \(actualSampleRate)Hz")
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

                // Perform conversion - track whether we've provided input data
                // nonisolated(unsafe) is safe here because convert() calls inputBlock synchronously
                var error: NSError?
                nonisolated(unsafe) var inputDataProvided = false
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if inputDataProvided {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    inputDataProvided = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if let error = error {
                    print("❌ Error converting audio buffer: \(error)")
                    return
                }

                // Only write if conversion produced data
                guard status != .error && convertedBuffer.frameLength > 0 else {
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

        // Use recording format's channel count (preserve stereo if available)
        settings[AVNumberOfChannelsKey] = recordingFormat.channelCount

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
