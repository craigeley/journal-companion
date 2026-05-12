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

    private func canonicalFileURL(filename: String) -> URL {
        VaultPaths.url(for: .media, in: vaultURL).appendingPathComponent(filename)
    }

    /// Locate an existing media file. Looks in the canonical (flat) location first,
    /// then falls back to the legacy `Media/` folder for pre-migration files.
    private func locateExistingFileURL(filename: String) -> URL? {
        let canonical = canonicalFileURL(filename: filename)
        if fileManager.fileExists(atPath: canonical.path) {
            return canonical
        }
        if let legacyDir = VaultPaths.legacyURL(for: .media, in: vaultURL) {
            let legacy = legacyDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: legacy.path) {
                return legacy
            }
        }
        return nil
    }

    /// Create a new media file
    func write(media: Media) async throws {
        // Access properties once at the start
        let filename = await MainActor.run { media.filename }
        let markdown = await MainActor.run { media.toMarkdown() }

        if locateExistingFileURL(filename: filename) != nil {
            throw MediaError.fileAlreadyExists(filename)
        }

        let fileURL = canonicalFileURL(filename: filename)
        let directoryURL = fileURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created media file: \(filename)")
    }

    /// Update an existing media file
    func update(media: Media) async throws {
        // Access properties once at the start
        let filename = await MainActor.run { media.filename }
        let markdown = await MainActor.run { media.toMarkdown() }

        guard let fileURL = locateExistingFileURL(filename: filename) else {
            throw MediaError.fileNotFound(filename)
        }

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated media: \(filename)")
    }

    /// Delete a media file
    func delete(media: Media) async throws {
        let filename = await MainActor.run { media.filename }

        guard let fileURL = locateExistingFileURL(filename: filename) else {
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
