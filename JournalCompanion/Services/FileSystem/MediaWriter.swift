//
//  MediaWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of media files
//

import Foundation

actor MediaWriter {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Create a new media file
    func write(media: Media) async throws {
        // Access properties once at the start
        let filename = await MainActor.run { media.filename }
        let markdown = await MainActor.run { media.toMarkdown() }

        let mediaDirectory = vaultURL.appendingPathComponent("Media")
        let fileURL = mediaDirectory.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            throw MediaError.fileAlreadyExists(filename)
        }

        // Create Media directory if needed
        if !fileManager.fileExists(atPath: mediaDirectory.path) {
            try fileManager.createDirectory(
                at: mediaDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Write file atomically
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created media file: \(filename)")
    }

    /// Update an existing media file
    func update(media: Media) async throws {
        // Access properties once at the start
        let filename = await MainActor.run { media.filename }
        let markdown = await MainActor.run { media.toMarkdown() }

        let mediaDirectory = vaultURL.appendingPathComponent("Media")
        let fileURL = mediaDirectory.appendingPathComponent(filename)

        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw MediaError.fileNotFound(filename)
        }

        // Write atomically
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated media: \(filename)")
    }

    /// Delete a media file
    func delete(media: Media) async throws {
        let filename = await MainActor.run { media.filename }

        let mediaDirectory = vaultURL.appendingPathComponent("Media")
        let fileURL = mediaDirectory.appendingPathComponent(filename)

        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw MediaError.fileNotFound(filename)
        }

        try fileManager.removeItem(at: fileURL)

        print("✓ Deleted media: \(filename)")
    }
}

// MARK: - Errors
enum MediaError: LocalizedError {
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case invalidMedia

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Media file not found: \(name)"
        case .fileAlreadyExists(let name):
            return "Media file already exists: \(name)"
        case .invalidMedia:
            return "Media data is invalid."
        }
    }
}
