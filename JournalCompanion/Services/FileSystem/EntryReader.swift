//
//  EntryReader.swift
//  JournalCompanion
//
//  Reads and parses entry files from the vault
//

import Foundation

actor EntryReader {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Load all entries from the vault
    func loadEntries(limit: Int? = nil) async throws -> [Entry] {
        let entriesURL = vaultURL.appendingPathComponent("Entries")

        guard fileManager.fileExists(atPath: entriesURL.path) else {
            print("⚠️ Entries directory not found")
            return []
        }

        // First, collect all file URLs synchronously
        var fileURLs: [URL] = []
        if let enumerator = fileManager.enumerator(
            at: entriesURL,
            includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            let allItems = enumerator.allObjects as? [URL] ?? []
            fileURLs = allItems.filter { $0.pathExtension == "md" }
        }

        // Then parse entries asynchronously
        var entries: [Entry] = []
        for fileURL in fileURLs {
            if let entry = try? await parseEntry(from: fileURL) {
                entries.append(entry)
            }
        }

        // Sort by date (newest first)
        entries.sort { $0.dateCreated > $1.dateCreated }

        // Apply limit AFTER sorting (to get most recent entries)
        if let limit = limit {
            entries = Array(entries.prefix(limit))
        }

        print("✓ Loaded \(entries.count) entries")
        return entries
    }

    /// Parse an entry from a markdown file
    private func parseEntry(from fileURL: URL) async throws -> Entry? {
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        // Split into frontmatter and content
        let components = content.components(separatedBy: "---\n")
        guard components.count >= 3 else {
            print("⚠️ Invalid entry format: \(fileURL.lastPathComponent)")
            return nil
        }

        let frontmatter = components[1]
        let bodyContent = components.dropFirst(2).joined(separator: "---\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse YAML frontmatter
        var dateCreated: Date?
        var tags: [String] = []
        var place: String?
        let placeCallout: String? = nil  // Not stored in entry files, only used during creation
        var temperature: Int?
        var condition: String?
        var aqi: Int?
        var humidity: Int?

        let lines = frontmatter.components(separatedBy: .newlines)
        var inTags = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("date_created:") {
                let dateString = trimmed.replacingOccurrences(of: "date_created:", with: "").trimmingCharacters(in: .whitespaces)

                // Try ISO8601 with fractional seconds first (standard format)
                let formatterWithFractional = ISO8601DateFormatter()
                formatterWithFractional.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone, .withFractionalSeconds]
                dateCreated = formatterWithFractional.date(from: dateString)

                // Fallback: ISO8601 without fractional seconds (backward compatibility)
                if dateCreated == nil {
                    let formatterWithoutFractional = ISO8601DateFormatter()
                    formatterWithoutFractional.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
                    dateCreated = formatterWithoutFractional.date(from: dateString)
                }
            } else if trimmed.hasPrefix("tags:") {
                let tagsString = trimmed.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)

                // Check if it's inline format: tags: [tag1, tag2, tag3]
                if tagsString.hasPrefix("[") && tagsString.hasSuffix("]") {
                    let tagsContent = tagsString.dropFirst().dropLast()
                    tags = tagsContent.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                } else if tagsString.isEmpty {
                    // YAML array format starts on next lines
                    inTags = true
                }
            } else if inTags && trimmed.hasPrefix("- ") {
                let tag = trimmed.replacingOccurrences(of: "- ", with: "")
                tags.append(tag)
            } else if trimmed.hasPrefix("place:") {
                inTags = false
                let placeString = trimmed.replacingOccurrences(of: "place:", with: "").trimmingCharacters(in: .whitespaces)
                // Extract place name from wikilink [[Name]]
                place = placeString.replacingOccurrences(of: "\"[[", with: "")
                    .replacingOccurrences(of: "]]\"", with: "")
            } else if trimmed.hasPrefix("temp:") {
                inTags = false
                let tempString = trimmed.replacingOccurrences(of: "temp:", with: "").trimmingCharacters(in: .whitespaces)
                temperature = Int(tempString)
            } else if trimmed.hasPrefix("cond:") {
                inTags = false
                condition = trimmed.replacingOccurrences(of: "cond:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("humidity:") {
                inTags = false
                let humidityString = trimmed.replacingOccurrences(of: "humidity:", with: "").trimmingCharacters(in: .whitespaces)
                humidity = Int(humidityString)
            } else if trimmed.hasPrefix("aqi:") {
                inTags = false
                let aqiString = trimmed.replacingOccurrences(of: "aqi:", with: "").trimmingCharacters(in: .whitespaces)
                aqi = Int(aqiString)
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("-") {
                inTags = false
            }
        }

        guard let date = dateCreated else {
            print("⚠️ Missing date_created in: \(fileURL.lastPathComponent)")
            return nil
        }

        // Generate ID from filename (without .md extension)
        let id = fileURL.deletingPathExtension().lastPathComponent

        return Entry(
            id: id,
            dateCreated: date,
            tags: tags,
            place: place,
            placeCallout: placeCallout,
            content: bodyContent,
            temperature: temperature,
            condition: condition,
            aqi: aqi,
            humidity: humidity
        )
    }
}
