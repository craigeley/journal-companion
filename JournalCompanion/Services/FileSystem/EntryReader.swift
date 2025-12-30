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

        // Split body content into user content and preserved sections
        // Find first line starting with markdown header (# ## ### etc.)
        let (userContent, preservedSections) = splitContentAtFirstHeader(bodyContent)

        // Parse YAML frontmatter
        var dateCreated: Date?
        var tags: [String] = []
        var place: String?
        var location: String?
        var people: [String] = []
        var temperature: Int?
        var condition: String?
        var aqi: Int?
        var humidity: Int?
        var moodValence: Double?
        var moodLabels: [String] = []
        var moodAssociations: [String] = []
        var audioAttachments: [String] = []
        var recordingDevice: String?
        var sampleRate: Int?
        var bitDepth: Int?

        // Track unknown YAML fields for preservation
        var unknownFields: [String: YAMLValue] = [:]
        var unknownFieldsOrder: [String] = []

        let lines = frontmatter.components(separatedBy: .newlines)
        var inTags = false
        var inPeople = false
        var inMoodLabels = false
        var inMoodAssociations = false
        var inAudioAttachments = false
        var inUnknownArray = false
        var currentUnknownArrayKey: String?

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
                inPeople = false
                let placeString = trimmed.replacingOccurrences(of: "place:", with: "").trimmingCharacters(in: .whitespaces)
                // Extract place name from wikilink [[Name]]
                place = placeString.replacingOccurrences(of: "\"[[", with: "")
                    .replacingOccurrences(of: "]]\"", with: "")
            } else if trimmed.hasPrefix("location:") {
                inTags = false
                inPeople = false
                location = trimmed.replacingOccurrences(of: "location:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("people:") {
                inTags = false
                inPeople = true
                let peopleString = trimmed.replacingOccurrences(of: "people:", with: "").trimmingCharacters(in: .whitespaces)

                // Check if inline format: people: [[[Name1]], [[Name2]]]
                if !peopleString.isEmpty {
                    // For inline, we would need to parse multiple wikilinks
                    // But our YAML format uses multi-line array, so this should be empty
                    inPeople = true
                }
            } else if inPeople && trimmed.hasPrefix("- ") {
                // Extract person name from wikilink: - "[[Name]]"
                let value = trimmed.replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "\"[[", with: "")
                    .replacingOccurrences(of: "]]\"", with: "")
                people.append(value)
            } else if trimmed.hasPrefix("temp:") {
                inPeople = false
                inTags = false
                let tempString = trimmed.replacingOccurrences(of: "temp:", with: "").trimmingCharacters(in: .whitespaces)
                temperature = Int(tempString)
            } else if trimmed.hasPrefix("cond:") {
                inTags = false
                inPeople = false
                condition = trimmed.replacingOccurrences(of: "cond:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("humidity:") {
                inTags = false
                inPeople = false
                let humidityString = trimmed.replacingOccurrences(of: "humidity:", with: "").trimmingCharacters(in: .whitespaces)
                humidity = Int(humidityString)
            } else if trimmed.hasPrefix("aqi:") {
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = false
                let aqiString = trimmed.replacingOccurrences(of: "aqi:", with: "").trimmingCharacters(in: .whitespaces)
                aqi = Int(aqiString)
            } else if trimmed.hasPrefix("mood_valence:") {
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = false
                let valenceString = trimmed.replacingOccurrences(of: "mood_valence:", with: "").trimmingCharacters(in: .whitespaces)
                moodValence = Double(valenceString)
            } else if trimmed.hasPrefix("mood_labels:") {
                inTags = false
                inPeople = false
                inMoodLabels = true
                inMoodAssociations = false
            } else if inMoodLabels && trimmed.hasPrefix("- ") {
                let label = trimmed.replacingOccurrences(of: "- ", with: "")
                moodLabels.append(label)
            } else if trimmed.hasPrefix("mood_associations:") {
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = true
            } else if inMoodAssociations && trimmed.hasPrefix("- ") {
                let association = trimmed.replacingOccurrences(of: "- ", with: "")
                moodAssociations.append(association)
            } else if trimmed.hasPrefix("audio_attachments:") {
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = false
                inAudioAttachments = true
            } else if inAudioAttachments && trimmed.hasPrefix("- ") {
                let filename = trimmed.replacingOccurrences(of: "- ", with: "").trimmingCharacters(in: .whitespaces)
                audioAttachments.append(filename)
            } else if trimmed.hasPrefix("recording_device:") {
                inAudioAttachments = false
                let deviceString = trimmed.replacingOccurrences(of: "recording_device:", with: "").trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
                recordingDevice = deviceString
            } else if trimmed.hasPrefix("sample_rate:") {
                inAudioAttachments = false
                let rateString = trimmed.replacingOccurrences(of: "sample_rate:", with: "").trimmingCharacters(in: .whitespaces)
                sampleRate = Int(rateString)
            } else if trimmed.hasPrefix("bit_depth:") {
                inAudioAttachments = false
                let depthString = trimmed.replacingOccurrences(of: "bit_depth:", with: "").trimmingCharacters(in: .whitespaces)
                bitDepth = Int(depthString)
            } else if inUnknownArray && trimmed.hasPrefix("- "),
                      let arrayKey = currentUnknownArrayKey {
                // Continue parsing unknown array
                let item = trimmed.replacingOccurrences(of: "- ", with: "").trimmingCharacters(in: .whitespaces)
                if case .array(var arr) = unknownFields[arrayKey] {
                    arr.append(item)
                    unknownFields[arrayKey] = .array(arr)
                }
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("-"),
                      let colonIndex = trimmed.firstIndex(of: ":") {
                // Reset all array flags
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = false
                inUnknownArray = false

                // Check if this is an unknown field
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)

                if !isKnownField(key) {
                    unknownFieldsOrder.append(key)

                    let valueString = String(trimmed[trimmed.index(after: colonIndex)...])
                        .trimmingCharacters(in: .whitespaces)

                    if valueString.isEmpty {
                        // Likely an array - next lines will have "- " items
                        unknownFields[key] = .array([])
                        inUnknownArray = true
                        currentUnknownArrayKey = key
                    } else {
                        unknownFields[key] = parseYAMLValue(valueString)
                    }
                }
            } else if !trimmed.isEmpty {
                // Reset flags for non-field lines
                inTags = false
                inPeople = false
                inMoodLabels = false
                inMoodAssociations = false
                inUnknownArray = false
            }
        }

        guard let date = dateCreated else {
            print("⚠️ Missing date_created in: \(fileURL.lastPathComponent)")
            return nil
        }

        // Generate ID from filename (without .md extension)
        let id = fileURL.deletingPathExtension().lastPathComponent

        var entry = Entry(
            id: id,
            dateCreated: date,
            tags: tags,
            place: place,
            people: people,
            placeCallout: nil,  // Will be looked up from Places at display time
            location: location,
            content: userContent,
            preservedSections: preservedSections,
            temperature: temperature,
            condition: condition,
            aqi: aqi,
            humidity: humidity,
            moodValence: moodValence,
            moodLabels: moodLabels.isEmpty ? nil : moodLabels,
            moodAssociations: moodAssociations.isEmpty ? nil : moodAssociations,
            audioAttachments: audioAttachments.isEmpty ? nil : audioAttachments,
            recordingDevice: recordingDevice,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            unknownFields: unknownFields,
            unknownFieldsOrder: unknownFieldsOrder
        )

        // Auto-sync stale audio entry content from SRT files
        if isAudioContentStale(entry: entry) {
            let audioFileManager = AudioFileManager(vaultURL: vaultURL)
            let entryWriter = EntryWriter(vaultURL: vaultURL)

            do {
                try await entryWriter.mirrorTranscriptsToContent(
                    entry: &entry,
                    audioFileManager: audioFileManager
                )
                print("✓ Auto-synced stale audio entry content: \(entry.id)")
            } catch {
                print("⚠️ Failed to auto-sync audio entry content: \(error)")
                // Non-fatal - return entry with existing content
            }
        }

        return entry
    }

    /// Check if a YAML key is a known field
    private func isKnownField(_ key: String) -> Bool {
        ["date_created", "tags", "place", "location", "people", "temp", "cond",
         "humidity", "aqi", "mood_valence", "mood_labels", "mood_associations",
         "audio_attachments", "recording_device", "sample_rate", "bit_depth"].contains(key)
    }

    /// Check if audio entry content is stale (needs re-mirroring from SRT)
    private func isAudioContentStale(entry: Entry) -> Bool {
        // Only check audio entries
        guard let audioAttachments = entry.audioAttachments, !audioAttachments.isEmpty else {
            return false
        }

        // Check if content contains expected audio embeds
        let content = entry.content

        // Each audio attachment should have a corresponding embed: ![[audio/filename]]
        for filename in audioAttachments {
            let expectedEmbed = "![[audio/\(filename)]]"
            if !content.contains(expectedEmbed) {
                print("⚠️ Missing embed for \(filename) in entry \(entry.id)")
                return true  // Stale - missing embed
            }
        }

        // Content appears valid
        return false
    }

    /// Parse a YAML value string into a YAMLValue type
    private func parseYAMLValue(_ value: String) -> YAMLValue {
        var cleaned = value

        // Remove quotes
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Try Int
        if let intValue = Int(cleaned) {
            return .int(intValue)
        }

        // Try Double
        if let doubleValue = Double(cleaned) {
            return .double(doubleValue)
        }

        // Try Bool
        if cleaned.lowercased() == "true" { return .bool(true) }
        if cleaned.lowercased() == "false" { return .bool(false) }

        // Try ISO8601 Date
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: cleaned) {
            return .date(date)
        }

        // Default to String
        return .string(cleaned)
    }

    /// Split content at first markdown header (# ## ### etc.)
    /// Returns (userContent, preservedSections)
    private func splitContentAtFirstHeader(_ content: String) -> (String, String?) {
        let lines = content.components(separatedBy: .newlines)

        // Find first line starting with # (markdown header)
        for (index, line) in lines.enumerated() {
            // Check if line starts with one or more # followed by space
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                // Find where the actual header text starts (after the #'s and space)
                if let firstNonHash = trimmed.firstIndex(where: { $0 != "#" }),
                   trimmed[firstNonHash] == " " {
                    // This is a valid markdown header
                    // Split here: everything before = user content, from here onward = preserved sections
                    let userContentLines = Array(lines[..<index])
                    let preservedLines = Array(lines[index...])

                    let userContent = userContentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    let preserved = preservedLines.joined(separator: "\n")

                    return (userContent, preserved.isEmpty ? nil : preserved)
                }
            }
        }

        // No header found - all content is user content
        return (content, nil)
    }
}
