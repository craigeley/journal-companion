//
//  Entry.swift
//  JournalCompanion
//
//  Core data model for journal entries
//

import Foundation

struct Entry: Identifiable, Codable, Sendable {
    let id: String
    var dateCreated: Date
    var tags: [String]
    var place: String?  // Place name (without brackets)
    var placeCallout: String?  // Place callout type (e.g., "cafe", "park", "home")
    var content: String

    // Optional weather data
    var temperature: Int?
    var condition: String?
    var aqi: Int?
    var humidity: Int?

    /// Generate filename in YYYYMMDDHHmm format
    nonisolated var filename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: dateCreated)
    }

    /// Generate directory path: Entries/YYYY/MM-Month/DD
    nonisolated var directoryPath: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: dateCreated)

        guard let year = components.year,
              let _ = components.month,
              let day = components.day else {
            return "Entries"
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM-MMMM"
        let monthString = monthFormatter.string(from: dateCreated)

        let dayString = String(format: "%02d", day)

        return "Entries/\(year)/\(monthString)/\(dayString)"
    }

    /// Convert entry to markdown format with YAML frontmatter
    nonisolated func toMarkdown() -> String {
        var yaml = "---\n"

        // Date in ISO 8601 with timezone
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone, .withFractionalSeconds]
        dateFormatter.timeZone = TimeZone.current
        yaml += "date_created: \(dateFormatter.string(from: dateCreated))\n"

        // Tags as YAML array (newline + dash format, NOT inline)
        if !tags.isEmpty {
            yaml += "tags:\n"
            for tag in tags {
                yaml += "  - \(tag)\n"
            }
        }

        // Place as wikilink (must be quoted)
        if let place = place, !place.isEmpty {
            yaml += "place: \"[[\(place)]]\"\n"
        }

        // Weather data (optional)
        if let temp = temperature {
            yaml += "temp: \(temp)\n"
        }
        if let cond = condition {
            yaml += "cond: \(cond)\n"
        }
        if let aqi = aqi {
            yaml += "aqi: \(aqi)\n"
        }
        if let humidity = humidity {
            yaml += "humidity: \(humidity)\n"
        }

        yaml += "---\n\n"

        return yaml + content + "\n"
    }

    /// Create a new entry with current timestamp
    static func create(content: String, place: String? = nil, tags: [String] = ["entry", "iPhone"]) -> Entry {
        Entry(
            id: UUID().uuidString,
            dateCreated: Date(),
            tags: tags,
            place: place,
            content: content
        )
    }
}

// MARK: - Validation
extension Entry {
    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
