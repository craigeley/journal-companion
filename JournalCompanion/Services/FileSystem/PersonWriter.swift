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

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Update an existing person
    func update(person: Person) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { person.filename }
        let markdown = await MainActor.run { person.toMarkdown() }

        let peopleDirectory = vaultURL.appendingPathComponent("People")
        let fileURL = peopleDirectory.appendingPathComponent(filename)

        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PersonError.fileNotFound(filename)
        }

        // Write atomically
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated person: \(filename)")
    }

    /// Create a new person file
    func write(person: Person) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { person.filename }
        let markdown = await MainActor.run { person.toMarkdown() }

        let peopleDirectory = vaultURL.appendingPathComponent("People")
        let fileURL = peopleDirectory.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            throw PersonError.fileAlreadyExists(filename)
        }

        // Create People directory if needed
        if !fileManager.fileExists(atPath: peopleDirectory.path) {
            try fileManager.createDirectory(
                at: peopleDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Write file atomically
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
