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

    /// Update an existing place
    func update(place: Place) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { place.filename }
        let template = await MainActor.run { templateManager.placeTemplate }
        let markdown = await MainActor.run { place.toMarkdown(template: template) }

        let placesDirectory = vaultURL.appendingPathComponent("Places")
        let fileURL = placesDirectory.appendingPathComponent(filename)

        // Verify file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PlaceError.fileNotFound(filename)
        }

        // Write atomically
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated place: \(filename)")
    }

    /// Create a new place file
    func write(place: Place) async throws {
        // Access MainActor properties once at the start
        let filename = await MainActor.run { place.filename }
        let template = await MainActor.run { templateManager.placeTemplate }
        let markdown = await MainActor.run { place.toMarkdown(template: template) }

        let placesDirectory = vaultURL.appendingPathComponent("Places")
        let fileURL = placesDirectory.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            throw PlaceError.fileAlreadyExists(filename)
        }

        // Create Places directory if needed
        if !fileManager.fileExists(atPath: placesDirectory.path) {
            try fileManager.createDirectory(
                at: placesDirectory,
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
