//
//  PlaceWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of place files
//

import Foundation

actor PlaceWriter {
    private let vaultURL: URL
    private let fileManager = FileManager.default
    private let templateManager: TemplateManager

    init(vaultURL: URL, templateManager: TemplateManager) {
        self.vaultURL = vaultURL
        self.templateManager = templateManager
    }

    /// Resolve the canonical location for a place file (flat root by default).
    private func canonicalFileURL(filename: String) -> URL {
        VaultPaths.url(for: .places, in: vaultURL).appendingPathComponent(filename)
    }

    /// Locate an existing place file. Looks in the canonical (flat) location first,
    /// then falls back to the legacy `Places/` folder for pre-migration files.
    private func locateExistingFileURL(filename: String) -> URL? {
        let canonical = canonicalFileURL(filename: filename)
        if fileManager.fileExists(atPath: canonical.path) {
            return canonical
        }
        if let legacyDir = VaultPaths.legacyURL(for: .places, in: vaultURL) {
            let legacy = legacyDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: legacy.path) {
                return legacy
            }
        }
        return nil
    }

    /// Update an existing place
    func update(place: Place) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { place.filename }
        let template = await MainActor.run { templateManager.placeTemplate }
        let markdown = await MainActor.run { place.toMarkdown(template: template) }

        guard let fileURL = locateExistingFileURL(filename: filename) else {
            throw PlaceError.fileNotFound(filename)
        }

        // Write atomically (in place — stays in legacy folder until migration moves it)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated place: \(filename)")
    }

    /// Create a new place file
    func write(place: Place) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { place.filename }
        let template = await MainActor.run { templateManager.placeTemplate }
        let markdown = await MainActor.run { place.toMarkdown(template: template) }

        // Reject if a place file with this name already exists in either layout
        if locateExistingFileURL(filename: filename) != nil {
            throw PlaceError.fileAlreadyExists(filename)
        }

        let fileURL = canonicalFileURL(filename: filename)
        let directoryURL = fileURL.deletingLastPathComponent()

        // Create parent directory if needed (no-op when writing to vault root)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Write file atomically
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created place file: \(filename)")
    }
}

// MARK: - Errors
enum PlaceError: LocalizedError {
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case invalidPlace

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Place file not found: \(name)"
        case .fileAlreadyExists(let name):
            return "Place file already exists: \(name)"
        case .invalidPlace:
            return "Place data is invalid."
        }
    }
}
