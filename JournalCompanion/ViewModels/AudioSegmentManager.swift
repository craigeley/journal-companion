//
//  AudioSegmentManager.swift
//  JournalCompanion
//
//  Manages multiple audio segments for an entry
//

import Foundation
import Combine

@MainActor
class AudioSegmentManager: ObservableObject {
    // MARK: - Segment Model

    struct Segment: Identifiable, Sendable {
        let id: String
        let tempURL: URL
        let duration: TimeInterval
        let transcription: String
        let timeRanges: [TimeRange]
        let format: AudioFormat
        let dateRecorded: Date

        init(
            id: String = UUID().uuidString,
            tempURL: URL,
            duration: TimeInterval,
            transcription: String,
            timeRanges: [TimeRange] = [],
            format: AudioFormat,
            dateRecorded: Date = Date()
        ) {
            self.id = id
            self.tempURL = tempURL
            self.duration = duration
            self.transcription = transcription
            self.timeRanges = timeRanges
            self.format = format
            self.dateRecorded = dateRecorded
        }

        var formattedDuration: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }

        var transcriptionPreview: String {
            if transcription.isEmpty {
                return "No transcription"
            }
            let preview = transcription.prefix(50)
            return preview.count < transcription.count ? String(preview) + "..." : String(preview)
        }
    }

    // MARK: - Published Properties

    @Published var segments: [Segment] = []

    // MARK: - Computed Properties

    var hasSegments: Bool {
        !segments.isEmpty
    }

    var segmentCount: Int {
        segments.count
    }

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var combinedTranscription: String {
        segments.map { $0.transcription }.joined(separator: " ")
    }

    // MARK: - Segment Management

    func addSegment(tempURL: URL, duration: TimeInterval, transcription: String, timeRanges: [TimeRange], format: AudioFormat) {
        let segment = Segment(
            tempURL: tempURL,
            duration: duration,
            transcription: transcription,
            timeRanges: timeRanges,
            format: format
        )
        segments.append(segment)
    }

    func removeSegment(_ segment: Segment) {
        segments.removeAll { $0.id == segment.id }

        // Clean up temp file
        try? FileManager.default.removeItem(at: segment.tempURL)
    }

    func removeSegment(at index: Int) {
        guard index < segments.count else { return }
        let segment = segments[index]
        segments.remove(at: index)

        // Clean up temp file
        try? FileManager.default.removeItem(at: segment.tempURL)
    }

    func clearAllSegments() {
        // Clean up all temp files
        for segment in segments {
            try? FileManager.default.removeItem(at: segment.tempURL)
        }

        segments.removeAll()
    }

    // MARK: - Persistence

    /// Save segments to vault and return entry data
    /// Time ranges are now stored in SRT sidecar files, not in YAML
    func saveSegments(for entry: Entry, audioFileManager: AudioFileManager) async throws -> (filenames: [String], transcriptions: [String]) {
        var filenames: [String] = []
        var transcriptions: [String] = []

        for (index, segment) in segments.enumerated() {
            // Write audio file AND SRT file to vault
            let filename = try await audioFileManager.writeAudioFile(
                from: segment.tempURL,
                for: entry,
                index: index + 1,
                format: segment.format,
                timeRanges: segment.timeRanges
            )
            filenames.append(filename)

            // Store transcription
            transcriptions.append(segment.transcription)
        }

        // Clean up temp files after successful save
        await audioFileManager.cleanupTempFiles(segments.map { $0.tempURL })

        return (filenames, transcriptions)
    }
}
