//
//  EntryWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of entry files
//

import Foundation
import CoreLocation

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
    func delete(entry: Entry, deleteAttachments: Bool = false) async throws {
        let directoryURL = vaultURL.appendingPathComponent(entry.directoryPath)
        let fileURL = directoryURL.appendingPathComponent(entry.filename + ".md")

        // Check that the file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EntryError.fileNotFound(entry.filename)
        }

        // Remove from day file first
        try await removeFromDayFile(entry: entry)

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
        let attachmentsDir = vaultURL.appendingPathComponent("_attachments")

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

                    // Add map to preserved sections (system-generated content)
                    let mapSection = "### Map\n![[maps/\(mapFilename)]]"
                    if let existing = updatedEntry.preservedSections {
                        updatedEntry.preservedSections = existing + "\n\n" + mapSection
                    } else {
                        updatedEntry.preservedSections = mapSection
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

        // Determine title: workout type > place name > "Entry"
        let title: String
        if let workoutType = entry.workoutType {
            title = workoutType
        } else if let place = entry.place {
            title = place
        } else {
            title = "Entry"
        }

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
            // Create new day file with weather metadata if location is set
            try fileManager.createDirectory(
                at: dayDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Try to fetch weather metadata
            let yamlHeader = await fetchWeatherMetadata(for: entry.dateCreated)

            content = """
            \(yamlHeader)

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

    /// Fetch weather metadata for a day file
    /// Returns YAML frontmatter with weather data if available, or minimal YAML as fallback
    private func fetchWeatherMetadata(for date: Date) async -> String {
        // Read weather location from UserDefaults
        let weatherLat = UserDefaults.standard.double(forKey: "dailyNoteWeatherLatitude")
        let weatherLon = UserDefaults.standard.double(forKey: "dailyNoteWeatherLongitude")

        // If no location set (both are 0.0), return minimal YAML
        guard weatherLat != 0.0 && weatherLon != 0.0 else {
            return "---\n---"
        }

        // Try to fetch weather data
        do {
            let weatherService = DailyWeatherService()
            let location = CLLocation(latitude: weatherLat, longitude: weatherLon)
            let forecast = try await weatherService.fetchDailyForecast(for: date, location: location)

            // Return YAML with weather metadata
            return """
            ---
            low_temp: \(forecast.lowTemp)
            high_temp: \(forecast.highTemp)
            sunrise: \(forecast.sunrise)
            sunset: \(forecast.sunset)
            ---
            """
        } catch {
            // If weather fetch fails, fall back to minimal YAML
            print("⚠️ Weather fetch failed (non-fatal): \(error)")
            return "---\n---"
        }
    }

    /// Determine callout type based on entry tags and place
    private func determineCallout(for entry: Entry) -> String {
        // Check for voice recorder entries
        if entry.tags.contains("voice_recorder") || entry.tags.contains("audio_journal") {
            return "audio-journal"
        }

        // Check for workout entries
        if entry.tags.contains("workout") {
            // Use specific callout for running workouts
            if entry.tags.contains("running") {
                return "run"
            }
            // Generic workout callout for other types
            return "workout"
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
