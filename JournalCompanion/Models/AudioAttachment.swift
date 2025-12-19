//
//  AudioAttachment.swift
//  JournalCompanion
//
//  Audio attachment metadata and configuration
//

import Foundation
import AVFoundation

// MARK: - Audio Attachment Model

struct AudioAttachment: Identifiable, Codable, Sendable {
    let id: String
    let filename: String
    let duration: TimeInterval
    let fileSize: Int64
    let format: AudioFormat
    let dateRecorded: Date
    var transcription: String?
    var timeRanges: [TimeRange]?
    var transcriptionState: TranscriptionState

    init(
        id: String = UUID().uuidString,
        filename: String,
        duration: TimeInterval,
        fileSize: Int64,
        format: AudioFormat,
        dateRecorded: Date = Date(),
        transcription: String? = nil,
        timeRanges: [TimeRange]? = nil,
        transcriptionState: TranscriptionState = .pending
    ) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.dateRecorded = dateRecorded
        self.transcription = transcription
        self.timeRanges = timeRanges
        self.transcriptionState = transcriptionState
    }
}

// MARK: - Audio Format

enum AudioFormat: String, Codable, CaseIterable, Sendable {
    case aac = "aac"
    case wav24 = "wav24"
    case wav32 = "wav32"

    nonisolated var fileExtension: String {
        switch self {
        case .aac:
            return "m4a"
        case .wav24, .wav32:
            return "wav"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .aac:
            return "AAC (Lossy, 256kbps)"
        case .wav24:
            return "WAV 24-bit (Lossless)"
        case .wav32:
            return "WAV 32-bit Float (Lossless, Native)"
        }
    }

    nonisolated var codecSettings: [String: Any] {
        switch self {
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: 256000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        case .wav24:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
        case .wav32:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
        }
    }
}

// MARK: - Time Range

struct TimeRange: Codable, Sendable, Hashable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval

    var duration: TimeInterval {
        end - start
    }

    func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }

    // Encode as "start-end" for YAML storage
    func encode() -> String {
        "\(start)-\(end)"
    }

    // Decode from "start-end" string
    static func decode(_ encoded: String) -> TimeRange? {
        let parts = encoded.split(separator: "-")
        guard parts.count == 2,
              let start = TimeInterval(parts[0]),
              let end = TimeInterval(parts[1]) else {
            return nil
        }
        return TimeRange(text: "", start: start, end: end)
    }
}

// MARK: - Transcription State

enum TranscriptionState: String, Codable {
    case pending
    case transcribing
    case completed
    case failed
    case unavailable

    var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .transcribing:
            return "Transcribing..."
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .unavailable:
            return "Unavailable"
        }
    }
}

// MARK: - Helper Extensions

extension AudioAttachment {
    /// Format duration as MM:SS
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format file size as human-readable string
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

extension [TimeRange] {
    /// Encode array of time ranges for YAML storage
    /// Format: "start1-end1,start2-end2,..."
    func encodeForYAML() -> String {
        map { $0.encode() }.joined(separator: ",")
    }

    /// Decode time ranges from YAML string
    static func decodeFromYAML(_ encoded: String) -> [TimeRange] {
        encoded.split(separator: ",").compactMap { segment in
            TimeRange.decode(String(segment))
        }
    }

    /// Find the time range containing the given time
    func range(at time: TimeInterval) -> TimeRange? {
        first { $0.contains(time) }
    }
}
