//
//  PersonWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of person files
//

import Foundation

actor PersonWriter {
    private let vaultURL: URL
    private let fileManager = FileManager.default
    private let templateManager: TemplateManager

    init(vaultURL: URL, templateManager: TemplateManager) {
        self.vaultURL = vaultURL
        self.templateManager = templateManager
    }

    private func canonicalFileURL(filename: String) -> URL {
        VaultPaths.url(for: .people, in: vaultURL).appendingPathComponent(filename)
    }

    /// Locate an existing person file. Looks in the canonical (flat) location first,
    /// then falls back to the legacy `People/` folder for pre-migration files.
    private func locateExistingFileURL(filename: String) -> URL? {
        let canonical = canonicalFileURL(filename: filename)
        if fileManager.fileExists(atPath: canonical.path) {
            return canonical
        }
        if let legacyDir = VaultPaths.legacyURL(for: .people, in: vaultURL) {
            let legacy = legacyDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: legacy.path) {
                return legacy
            }
        }
        return nil
    }

    /// Update an existing person
    func update(person: Person) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { person.filename }
        let template = await MainActor.run { templateManager.personTemplate }
        let markdown = await MainActor.run { person.toMarkdown(template: template) }

        guard let fileURL = locateExistingFileURL(filename: filename) else {
            throw PersonError.fileNotFound(filename)
        }

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated person: \(filename)")
    }

    /// Create a new person file
    func write(person: Person) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { person.filename }
        let template = await MainActor.run { templateManager.personTemplate }
        let markdown = await MainActor.run { person.toMarkdown(template: template) }

        if locateExistingFileURL(filename: filename) != nil {
            throw PersonError.fileAlreadyExists(filename)
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

        print("✓ Created person file: \(filename)")
    }
}

// MARK: - Errors
enum PersonError: LocalizedError {
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case invalidPerson

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Person file not found: \(name)"
        case .fileAlreadyExists(let name):
            return "Person file already exists: \(name)"
        case .invalidPerson:
            return "Person data is invalid."
        }
    }
}
