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

    /// Write audio file from temp location to vault
    /// Returns the filename for YAML storage
    func writeAudioFile(
        from tempURL: URL,
        for entry: Entry,
        index: Int,
        format: AudioFormat
    ) async throws -> String {
        // Ensure directory exists
        let audioDir = try await createAudioDirectory(for: entry)

        // Generate filename: YYYYMMDDHHmm-{index}.m4a
        let filename = "\(entry.filename)-\(index).\(format.fileExtension)"
        let destinationURL = audioDir.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw AudioFileError.fileAlreadyExists(filename)
        }

        // Copy temp file to vault
        try fileManager.copyItem(at: tempURL, to: destinationURL)

        print("✓ Wrote audio file: \(filename)")
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

    // MARK: - Private Helpers

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
