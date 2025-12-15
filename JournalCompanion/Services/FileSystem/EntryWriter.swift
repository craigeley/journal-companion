//
//  EntryWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of entry files
//

import Foundation

actor EntryWriter {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Write entry to file system
    func write(entry: Entry) async throws {
        let directoryURL = vaultURL.appendingPathComponent(entry.directoryPath)
        let fileURL = directoryURL.appendingPathComponent(entry.filename + ".md")

        // Check if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            throw EntryError.fileAlreadyExists(entry.filename)
        }

        // Create directory if needed
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write file atomically
        let markdown = entry.toMarkdown()
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created entry file: \(entry.filename).md")

        // Add to day file
        try await addToDayFile(entry: entry)
    }

    /// Add entry callout to day file
    private func addToDayFile(entry: Entry) async throws {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: entry.dateCreated)

        guard let year = components.year,
              let _ = components.month,
              let _ = components.day else {
            throw EntryError.invalidDate
        }

        // Generate day file path: Days/YYYY/MM-Month/YYYY-MM-DD.md
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM-MMMM"
        let monthString = monthFormatter.string(from: entry.dateCreated)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dayFilename = dayFormatter.string(from: entry.dateCreated) + ".md"

        let dayDir = vaultURL.appendingPathComponent("Days/\(year)/\(monthString)")
        let dayFileURL = dayDir.appendingPathComponent(dayFilename)

        // Determine callout type
        let calloutType = determineCallout(for: entry)

        // Format time string
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: entry.dateCreated)

        // Get place name or default title
        let title = entry.place ?? "Entry"

        // Get the entry filename for embedding
        let entryFilename = entry.filename

        // Create callout block
        let calloutBlock = """
        > [!\(calloutType)]- \(timeString) - \(title)
        > ![[\(entryFilename)]]

        """

        var content: String

        if fileManager.fileExists(atPath: dayFileURL.path) {
            // Read existing day file
            content = try String(contentsOf: dayFileURL, encoding: .utf8)

            // Check if this entry is already linked
            if content.contains("![[\(entryFilename)]]") {
                print("Entry already linked in day file: \(dayFilename)")
                return
            }

            // Find ### Entries section or append
            if let range = content.range(of: "### Entries\n") {
                // Insert after the ### Entries line
                let insertionPoint = range.upperBound
                content.insert(contentsOf: "\n" + calloutBlock, at: insertionPoint)
            } else {
                // Add Entries section at the end
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
                content += "\n\n### Entries\n\n" + calloutBlock
            }
        } else {
            // Create minimal day file
            try fileManager.createDirectory(
                at: dayDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            content = """
            ---
            ---

            ### Entries

            \(calloutBlock)
            """
        }

        // Write day file atomically
        try content.write(to: dayFileURL, atomically: true, encoding: .utf8)
        print("✓ Updated day file: \(dayFilename)")
    }

    /// Determine callout type based on entry tags and place
    private func determineCallout(for entry: Entry) -> String {
        // Check for voice recorder entries
        if entry.tags.contains("voice_recorder") || entry.tags.contains("audio_journal") {
            return "audio-journal"
        }

        // If entry has a place with a callout, use it
        if let placeCallout = entry.placeCallout, !placeCallout.isEmpty {
            return placeCallout
        }

        // Check for visit/checkin tags
        if entry.tags.contains("checkin") || entry.tags.contains("visit") {
            return "place"
        }

        // Default callout type
        return "note"
    }
}

// MARK: - Errors
enum EntryError: LocalizedError {
    case fileAlreadyExists(String)
    case invalidEntry
    case invalidDate
    case dayFileUpdateFailed

    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let name):
            return "Entry \(name) already exists. Please wait a minute and try again."
        case .invalidEntry:
            return "Entry data is invalid."
        case .invalidDate:
            return "Entry date is invalid."
        case .dayFileUpdateFailed:
            return "Failed to update day file."
        }
    }
}
