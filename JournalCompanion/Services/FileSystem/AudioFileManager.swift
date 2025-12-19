//
//  AudioFileManager.swift
//  JournalCompanion
//
//  Actor-based audio file management for vault storage
//

import Foundation

// MARK: - Audio File Manager

actor AudioFileManager {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    // MARK: - Directory Management

    /// Create _attachments/audio directory
    func createAudioDirectory(for entry: Entry) async throws -> URL {
        let audioDir = audioDirectory(for: entry)

        if !fileManager.fileExists(atPath: audioDir.path) {
            try fileManager.createDirectory(
                at: audioDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✓ Created audio directory: \(audioDir.lastPathComponent)")
        }

        return audioDir
    }

    /// Ensure root _attachments directory exists
    func ensureAttachmentsDirectory() async throws {
        let attachmentsDir = vaultURL.appendingPathComponent("_attachments")

        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try fileManager.createDirectory(
                at: attachmentsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✓ Created _attachments directory")
        }
    }

    // MARK: - Audio File Operations

    /// Write audio file and SRT subtitle file from temp location to vault
    /// Returns the filename for YAML storage
    func writeAudioFile(
        from tempURL: URL,
        for entry: Entry,
        index: Int,
        format: AudioFormat,
        timeRanges: [TimeRange]
    ) async throws -> String {
        // Ensure directory exists
        let audioDir = try await createAudioDirectory(for: entry)

        // Generate filenames: YYYYMMDDHHmm-{index}.ext
        let filename = "\(entry.filename)-\(index).\(format.fileExtension)"
        let srtFilename = "\(entry.filename)-\(index).srt"
        let destinationURL = audioDir.appendingPathComponent(filename)
        let srtURL = audioDir.appendingPathComponent(srtFilename)

        // Check if file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw AudioFileError.fileAlreadyExists(filename)
        }

        // Copy temp file to vault
        try fileManager.copyItem(at: tempURL, to: destinationURL)

        // Write SRT file with time ranges
        let srtContent = generateSRT(from: timeRanges)
        try srtContent.write(to: srtURL, atomically: true, encoding: .utf8)

        print("✓ Wrote audio file: \(filename)")
        print("✓ Wrote SRT file: \(srtFilename) (\(timeRanges.count) segments)")
        return filename
    }

    /// Delete audio file from vault
    func deleteAudioFile(filename: String, for entry: Entry) async throws {
        let audioDir = audioDirectory(for: entry)
        let fileURL = audioDir.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AudioFileError.fileNotFound(filename)
        }

        try fileManager.removeItem(at: fileURL)
        print("✓ Deleted audio file: \(filename)")
    }

    /// Get audio file URL for playback
    func audioURL(filename: String, for entry: Entry) async throws -> URL {
        let audioDir = audioDirectory(for: entry)
        let fileURL = audioDir.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AudioFileError.fileNotFound(filename)
        }

        return fileURL
    }

    /// Get file size for audio file
    func fileSize(filename: String, for entry: Entry) async throws -> Int64 {
        let fileURL = try await audioURL(filename: filename, for: entry)
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Clean up temporary audio files
    func cleanupTempFiles(_ urls: [URL]) async {
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
        print("✓ Cleaned up \(urls.count) temporary audio file(s)")
    }

    /// Check if audio file exists
    func fileExists(filename: String, for entry: Entry) async -> Bool {
        let audioDir = audioDirectory(for: entry)
        let fileURL = audioDir.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // MARK: - SRT Subtitle Operations

    /// Load time ranges from SRT sidecar file
    func loadTimeRanges(for audioFilename: String, entry: Entry) async throws -> [TimeRange] {
        let audioDir = audioDirectory(for: entry)

        // Replace audio extension with .srt
        let srtFilename = (audioFilename as NSString).deletingPathExtension + ".srt"
        let srtURL = audioDir.appendingPathComponent(srtFilename)

        guard fileManager.fileExists(atPath: srtURL.path) else {
            print("⚠️ No SRT file found for \(audioFilename)")
            return []
        }

        let content = try String(contentsOf: srtURL, encoding: .utf8)
        return parseSRT(content)
    }

    // MARK: - Private Helpers

    /// Generate SRT (SubRip) subtitle format from time ranges
    private func generateSRT(from timeRanges: [TimeRange]) -> String {
        var srt = ""
        for (index, range) in timeRanges.enumerated() {
            let sequenceNumber = index + 1
            let startTime = formatSRTTime(range.start)
            let endTime = formatSRTTime(range.end)

            srt += "\(sequenceNumber)\n"
            srt += "\(startTime) --> \(endTime)\n"
            srt += "\(range.text)\n"
            srt += "\n"
        }
        return srt
    }

    /// Format time as SRT timestamp (HH:MM:SS,mmm)
    private func formatSRTTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    /// Parse SRT format into TimeRange objects
    private func parseSRT(_ content: String) -> [TimeRange] {
        var ranges: [TimeRange] = []
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            // Parse timestamp line: "00:00:00,000 --> 00:00:02,160"
            let timeLine = lines[1]
            let timestamps = timeLine.components(separatedBy: " --> ")
            guard timestamps.count == 2 else { continue }

            let start = parseSRTTime(timestamps[0])
            let end = parseSRTTime(timestamps[1])

            // Text is everything from line 3 onwards
            let text = lines[2...].joined(separator: "\n")

            ranges.append(TimeRange(text: text, start: start, end: end))
        }

        return ranges
    }

    /// Parse SRT timestamp to seconds
    private func parseSRTTime(_ timestamp: String) -> TimeInterval {
        // Format: HH:MM:SS,mmm
        let parts = timestamp.components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secondsParts = parts[2].components(separatedBy: ",")
        let seconds = Double(secondsParts[0]) ?? 0
        let millis = secondsParts.count > 1 ? (Double(secondsParts[1]) ?? 0) / 1000 : 0

        return (hours * 3600) + (minutes * 60) + seconds + millis
    }

    /// Get audio directory path for entry
    /// Format: _attachments/audio/
    private func audioDirectory(for entry: Entry) -> URL {
        vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("audio")
    }
}

// MARK: - Errors

enum AudioFileError: LocalizedError {
    case fileAlreadyExists(String)
    case fileNotFound(String)
    case directoryCreationFailed
    case copyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let filename):
            return "Audio file already exists: \(filename)"
        case .fileNotFound(let filename):
            return "Audio file not found: \(filename)"
        case .directoryCreationFailed:
            return "Failed to create audio directory."
        case .copyFailed(let error):
            return "Failed to copy audio file: \(error.localizedDescription)"
        }
    }
}
