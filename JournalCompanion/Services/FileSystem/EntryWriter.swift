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

    /// Update an existing entry
    func update(entry: Entry) async throws {
        let directoryURL = vaultURL.appendingPathComponent(entry.directoryPath)
        let fileURL = directoryURL.appendingPathComponent(entry.filename + ".md")

        // Check that the file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EntryError.fileNotFound(entry.filename)
        }

        // Generate updated markdown
        let markdown = entry.toMarkdown()

        // Overwrite the existing file
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Updated entry: \(entry.filename).md")
    }

    /// Update entry when date has changed (requires file migration)
    func updateWithDateChange(oldEntry: Entry, newEntry: Entry) async throws {
        // Validate old file exists
        let oldDirectoryURL = vaultURL.appendingPathComponent(oldEntry.directoryPath)
        let oldFileURL = oldDirectoryURL.appendingPathComponent(oldEntry.filename + ".md")

        guard fileManager.fileExists(atPath: oldFileURL.path) else {
            throw EntryError.fileNotFound(oldEntry.filename)
        }

        // Create new directory if needed
        let newDirectoryURL = vaultURL.appendingPathComponent(newEntry.directoryPath)
        try fileManager.createDirectory(
            at: newDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write entry to new location
        let newFileURL = newDirectoryURL.appendingPathComponent(newEntry.filename + ".md")
        let markdown = newEntry.toMarkdown()
        try markdown.write(to: newFileURL, atomically: true, encoding: .utf8)

        print("✓ Created entry file at new location: \(newEntry.filename).md")

        // Remove old file
        try fileManager.removeItem(at: oldFileURL)
        print("✓ Removed old entry file: \(oldEntry.filename).md")

        // Update day file references
        try await removeFromDayFile(entry: oldEntry)
        try await addToDayFile(entry: newEntry)

        print("✓ Migrated entry from \(oldEntry.filename) to \(newEntry.filename)")
    }

    /// Delete an entry
    func delete(entry: Entry) async throws {
        let directoryURL = vaultURL.appendingPathComponent(entry.directoryPath)
        let fileURL = directoryURL.appendingPathComponent(entry.filename + ".md")

        // Check that the file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EntryError.fileNotFound(entry.filename)
        }

        // Remove from day file first
        try await removeFromDayFile(entry: entry)

        // Delete the entry file
        try fileManager.removeItem(at: fileURL)

        print("✓ Deleted entry: \(entry.filename).md")
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
            if content.contains("### Entries\n") {
                // Append at the end of the file (chronological order)
                // Ensure proper spacing before new callout (need blank line separator)
                if content.hasSuffix("\n\n") {
                    // Already has blank line, just append
                    content.append(calloutBlock)
                } else if content.hasSuffix("\n") {
                    // Has one newline, add one more to create blank line
                    content.append("\n" + calloutBlock)
                } else {
                    // No newline, add two newlines then callout
                    content.append("\n\n" + calloutBlock)
                }
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

    /// Remove entry callout from day file
    private func removeFromDayFile(entry: Entry) async throws {
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

        // If day file doesn't exist, nothing to remove
        guard fileManager.fileExists(atPath: dayFileURL.path) else {
            return
        }

        // Read existing day file
        var content = try String(contentsOf: dayFileURL, encoding: .utf8)

        // Get the entry filename for matching
        let entryFilename = entry.filename

        // Check if this entry is referenced
        guard content.contains("![[\(entryFilename)]]") else {
            print("Entry not found in day file: \(dayFilename)")
            return
        }

        // Remove the callout block containing this entry
        // Pattern: Match from "> [!..." through the embed line and trailing newlines
        let pattern = "> \\[!.*?\\n> !\\[\\[\(NSRegularExpression.escapedPattern(for: entryFilename))\\]\\]\\n*"

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            content = regex.stringByReplacingMatches(
                in: content,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Write updated day file atomically
        try content.write(to: dayFileURL, atomically: true, encoding: .utf8)
        print("✓ Removed entry from day file: \(dayFilename)")
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
    case fileNotFound(String)
    case invalidEntry
    case invalidDate
    case dayFileUpdateFailed

    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let name):
            return "Entry \(name) already exists. Please wait a minute and try again."
        case .fileNotFound(let name):
            return "Entry file not found: \(name)"
        case .invalidEntry:
            return "Entry data is invalid."
        case .invalidDate:
            return "Entry date is invalid."
        case .dayFileUpdateFailed:
            return "Failed to update day file."
        }
    }
}
