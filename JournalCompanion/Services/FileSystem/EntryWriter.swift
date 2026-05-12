//
//  EntryWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of entry files
//

import Foundation
import CoreLocation

actor EntryWriter {
    // NOTE: Daily note writing (callouts, weather, etc.) has been removed.
    // Daily notes are now managed by a separate process.
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Resolve the canonical location for a new entry file (flat root by default).
    private func canonicalFileURL(for entry: Entry) -> URL {
        VaultPaths.url(for: .entries, in: vaultURL)
            .appendingPathComponent(entry.filename + ".md")
    }

    /// Locate an existing entry file. Looks in the canonical (flat) location first,
    /// then falls back to the legacy date-nested path for pre-migration files.
    private func locateExistingFileURL(for entry: Entry) -> URL? {
        let canonical = canonicalFileURL(for: entry)
        if fileManager.fileExists(atPath: canonical.path) {
            return canonical
        }
        let legacy = vaultURL
            .appendingPathComponent(entry.legacyDirectoryPath)
            .appendingPathComponent(entry.filename + ".md")
        if fileManager.fileExists(atPath: legacy.path) {
            return legacy
        }
        return nil
    }

    /// Write entry to file system
    func write(entry: Entry) async throws {
        let fileURL = canonicalFileURL(for: entry)

        // Reject if a file with this filename already exists in either layout.
        if locateExistingFileURL(for: entry) != nil {
            throw EntryError.fileAlreadyExists(entry.filename)
        }

        // Create directory if needed (no-op when writing to vault root).
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write file atomically
        let markdown = entry.toMarkdown()
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created entry file: \(entry.filename).md")
    }

    /// Update an existing entry
    func update(entry: Entry) async throws {
        guard let fileURL = locateExistingFileURL(for: entry) else {
            throw EntryError.fileNotFound(entry.filename)
        }

        // Generate updated markdown
        let markdown = entry.toMarkdown()

        // Overwrite the existing file in place (stays in legacy folder until migration).
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated entry: \(entry.filename).md")
    }

    /// Update entry when date has changed (filename and possibly folder change).
    func updateWithDateChange(oldEntry: Entry, newEntry: Entry) async throws {
        // Validate old file exists (in either layout)
        guard let oldFileURL = locateExistingFileURL(for: oldEntry) else {
            throw EntryError.fileNotFound(oldEntry.filename)
        }

        // Always write the new file to the canonical (flat) location.
        let newFileURL = canonicalFileURL(for: newEntry)
        let newDirectoryURL = newFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: newDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let markdown = newEntry.toMarkdown()
        try markdown.write(to: newFileURL, atomically: true, encoding: .utf8)

        print("✓ Created entry file at new location: \(newEntry.filename).md")

        // Remove old file
        try fileManager.removeItem(at: oldFileURL)
        print("✓ Removed old entry file: \(oldEntry.filename).md")

        print("✓ Migrated entry from \(oldEntry.filename) to \(newEntry.filename)")
    }

    /// Delete an entry
    func delete(entry: Entry, deleteAttachments: Bool = false) async throws {
        guard let fileURL = locateExistingFileURL(for: entry) else {
            throw EntryError.fileNotFound(entry.filename)
        }

        // Delete attachments if requested
        if deleteAttachments {
            try await deleteEntryAttachments(entry: entry)
        }

        // Delete the entry file
        try fileManager.removeItem(at: fileURL)

        print("✓ Deleted entry: \(entry.filename).md")
    }

    /// Delete all attachments associated with an entry
    func deleteEntryAttachments(entry: Entry) async throws {
        let attachmentsDir = VaultPaths.url(for: .attachments, in: vaultURL)

        // Delete audio files and their .srt sidecar files
        if let audioFiles = entry.audioAttachments {
            let audioDir = attachmentsDir.appendingPathComponent("audio")

            for audioFile in audioFiles {
                let audioURL = audioDir.appendingPathComponent(audioFile)
                if fileManager.fileExists(atPath: audioURL.path) {
                    try fileManager.removeItem(at: audioURL)
                    print("✓ Deleted audio file: \(audioFile)")
                }

                // Delete .srt sidecar file
                let srtFilename = (audioFile as NSString).deletingPathExtension + ".srt"
                let srtURL = audioDir.appendingPathComponent(srtFilename)
                if fileManager.fileExists(atPath: srtURL.path) {
                    try fileManager.removeItem(at: srtURL)
                    print("✓ Deleted SRT file: \(srtFilename)")
                }
            }
        }

        // Delete GPX route file
        if let routeFile = entry.routeFile {
            let routesDir = attachmentsDir.appendingPathComponent("routes")
            let routeURL = routesDir.appendingPathComponent(routeFile)
            if fileManager.fileExists(atPath: routeURL.path) {
                try fileManager.removeItem(at: routeURL)
                print("✓ Deleted GPX route: \(routeFile)")
            }
        }

        // Delete map snapshot (inferred from entry ID)
        let mapsDir = attachmentsDir.appendingPathComponent("maps")
        let mapFilename = "\(entry.filename)-map.png"
        let mapURL = mapsDir.appendingPathComponent(mapFilename)
        if fileManager.fileExists(atPath: mapURL.path) {
            try fileManager.removeItem(at: mapURL)
            print("✓ Deleted map snapshot: \(mapFilename)")
        }

        print("✓ Deleted all attachments for entry: \(entry.filename)")
    }

    /// Mirror SRT transcripts to entry content field
    /// Entry content becomes a readable copy of SRT text for Obsidian
    func mirrorTranscriptsToContent(
        entry: inout Entry,
        audioFileManager: AudioFileManager
    ) async throws {
        // Only process audio entries
        guard let audioAttachments = entry.audioAttachments, !audioAttachments.isEmpty else {
            return
        }

        var contentParts: [String] = []

        // Process each audio attachment
        for audioFilename in audioAttachments {
            // Build audio embed for Obsidian
            let embed = "![[audio/\(audioFilename)]]"

            // Extract transcript text from SRT file
            let transcriptText = try await audioFileManager.extractTranscriptText(
                for: audioFilename,
                entry: entry
            )

            // Add embed + transcript to content
            contentParts.append(embed)
            contentParts.append("")  // Blank line
            contentParts.append(transcriptText)
        }

        // Update entry content with mirrored transcripts
        entry.content = contentParts.joined(separator: "\n")

        print("✓ Mirrored \(audioAttachments.count) transcript(s) to entry content")
    }

    /// Write workout entry with route data
    /// Non-fatal: If GPX/map generation fails, entry still saves
    func writeWorkoutEntry(
        entry: Entry,
        coordinates: [CLLocationCoordinate2D]?,
        workoutName: String,
        workoutType: String
    ) async throws {
        var updatedEntry = entry

        // Generate GPX if coordinates available
        if let coords = coordinates, !coords.isEmpty {
            do {
                let gpxWriter = GPXWriter(vaultURL: vaultURL)
                let gpxFilename = try await gpxWriter.write(
                    coordinates: coords,
                    for: entry.id,
                    workoutName: workoutName,
                    workoutType: workoutType,
                    startDate: entry.dateCreated
                )

                // Add route_file to unknownFields (order already set by WorkoutSyncViewModel)
                updatedEntry.unknownFields["route_file"] = .string(gpxFilename)

                print("✓ GPX file written successfully")

                // Generate map snapshot (non-fatal)
                do {
                    let mapGenerator = MapSnapshotGenerator(vaultURL: vaultURL)
                    let mapFilename = try await mapGenerator.generateMap(
                        coordinates: coords,
                        for: entry.id
                    )

                    // Append the map embed to the entry body.
                    let mapSection = "### Map\n![[maps/\(mapFilename)]]"
                    if updatedEntry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        updatedEntry.content = mapSection
                    } else {
                        updatedEntry.content += "\n\n" + mapSection
                    }

                    print("✓ Map snapshot generated successfully")
                } catch {
                    print("⚠️ Map generation failed (non-fatal): \(error)")
                }
            } catch {
                print("⚠️ GPX write failed (non-fatal): \(error)")
            }
        }

        // Write entry (always succeeds even if GPX/map failed)
        try await write(entry: updatedEntry)
    }

}

// MARK: - Errors
enum EntryError: LocalizedError {
    case fileAlreadyExists(String)
    case fileNotFound(String)
    case invalidEntry

    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let name):
            return "Entry \(name) already exists. Please wait a minute and try again."
        case .fileNotFound(let name):
            return "Entry file not found: \(name)"
        case .invalidEntry:
            return "Entry data is invalid."
        }
    }
}
