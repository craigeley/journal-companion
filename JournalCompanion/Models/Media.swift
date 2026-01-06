//
//  Media.swift
//  JournalCompanion
//
//  Core data model for media entries (movies, TV shows, books, podcasts, albums)
//

import Foundation
import SwiftUI

// MARK: - MediaType Enum

/// Type-safe enum for media types
enum MediaType: String, Codable, CaseIterable, Sendable, Hashable {
    case movie
    case tvShow = "tv_show"
    case book
    case podcast
    case album

    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tvShow: return "TV Show"
        case .book: return "Book"
        case .podcast: return "Podcast"
        case .album: return "Album"
        }
    }

    var systemImage: String {
        switch self {
        case .movie: return "film.fill"
        case .tvShow: return "tv.fill"
        case .book: return "book.fill"
        case .podcast: return "mic.fill"
        case .album: return "music.note.list"
        }
    }

    var color: Color {
        switch self {
        case .movie: return .indigo
        case .tvShow: return .blue
        case .book: return .orange
        case .podcast: return .purple
        case .album: return .pink
        }
    }

    /// iTunes Search API media parameter
    nonisolated var iTunesMedia: String {
        switch self {
        case .movie: return "movie"
        case .tvShow: return "tvShow"
        case .book: return "ebook"
        case .podcast: return "podcast"
        case .album: return "music"
        }
    }

    /// iTunes Search API entity parameter
    nonisolated var iTunesEntity: String {
        switch self {
        case .movie: return "movie"
        case .tvShow: return "tvSeason"
        case .book: return "ebook"
        case .podcast: return "podcast"
        case .album: return "album"
        }
    }
}

// MARK: - Media Model

struct Media: Identifiable, Codable, Sendable, Hashable {
    // Hashable conformance based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Media, rhs: Media) -> Bool {
        lhs.id == rhs.id
    }

    let id: String  // Sanitized filename (without .md extension)
    var title: String
    var mediaType: MediaType
    var creator: String?  // Artist, author, director, host
    var releaseYear: Int?
    var genre: String?
    var artworkURL: String?  // Cover image URL
    var iTunesID: String?  // For linking back to iTunes/Apple
    var iTunesURL: String?  // Direct link to iTunes Store
    var tags: [String]
    var aliases: [String]
    var content: String  // Body text (user notes/review)

    // Type-specific optional fields stored here
    var unknownFields: [String: YAMLValue]
    var unknownFieldsOrder: [String]

    var filename: String {
        id + ".md"
    }

    /// Sanitize filename using same regex as Ruby scripts: [<>:"\/\\|?*]
    static func sanitizeFilename(_ name: String) -> String {
        let pattern = "[<>:\"\\/\\\\|?*]"
        let sanitized = name.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Convert media to markdown format with YAML frontmatter
    func toMarkdown() -> String {
        var yaml = "---\n"

        // Required fields
        yaml += "type: \(mediaType.rawValue)\n"
        yaml += "title: \(title)\n"

        // Optional core fields
        if let creator = creator, !creator.isEmpty {
            yaml += "creator: \(creator)\n"
        }

        if let releaseYear = releaseYear {
            yaml += "release_year: \(releaseYear)\n"
        }

        if let genre = genre, !genre.isEmpty {
            yaml += "genre: \(genre)\n"
        }

        if let artworkURL = artworkURL, !artworkURL.isEmpty {
            yaml += "artwork_url: \(artworkURL)\n"
        }

        if let iTunesID = iTunesID, !iTunesID.isEmpty {
            yaml += "itunes_id: \"\(iTunesID)\"\n"
        }

        if let iTunesURL = iTunesURL, !iTunesURL.isEmpty {
            yaml += "itunes_url: \(iTunesURL)\n"
        }

        // Tags
        if !tags.isEmpty {
            yaml += "tags:\n"
            for tag in tags {
                yaml += "  - \(tag)\n"
            }
        }

        // Aliases
        if !aliases.isEmpty {
            yaml += "aliases:\n"
            for alias in aliases {
                yaml += "  - \(alias)\n"
            }
        } else {
            yaml += "aliases: []\n"
        }

        // Unknown fields (type-specific and user-added) in original order
        for key in unknownFieldsOrder {
            if let value = unknownFields[key] {
                yaml += formatYAMLField(key: key, value: value)
            }
        }

        yaml += "---\n\n"

        return yaml + content
    }

    /// Format a YAMLValue for output
    private func formatYAMLField(key: String, value: YAMLValue) -> String {
        switch value {
        case .string(let s):
            // Quote strings that might be interpreted as other types
            if s.contains(":") || s.contains("#") || s.hasPrefix("@") {
                return "\(key): \"\(s)\"\n"
            }
            return "\(key): \(s)\n"
        case .int(let i):
            return "\(key): \(i)\n"
        case .double(let d):
            // Format with reasonable precision
            if d == d.rounded() {
                return "\(key): \(Int(d))\n"
            }
            return "\(key): \(String(format: "%.1f", d))\n"
        case .bool(let b):
            return "\(key): \(b)\n"
        case .array(let arr):
            if arr.isEmpty {
                return "\(key): []\n"
            }
            var result = "\(key):\n"
            for item in arr {
                result += "  - \(item)\n"
            }
            return result
        case .date(let d):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return "\(key): \(formatter.string(from: d))\n"
        }
    }

    /// Parse Media from markdown file content
    nonisolated static func parse(from content: String, filename: String) -> Media? {
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }

        // Type is required
        guard let typeString = frontmatter["type"] as? String,
              let mediaType = MediaType(rawValue: typeString) else {
            return nil
        }

        let name = String(filename.dropLast(3))  // Remove .md extension

        // Title - use frontmatter title or filename
        let title = frontmatter["title"] as? String ?? name

        // Extract tags
        let tags: [String] = {
            if let tagArray = frontmatter["tags"] as? [String] {
                return tagArray
            } else if let tagString = frontmatter["tags"] as? String {
                let cleaned = tagString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                return cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return []
        }()

        // Extract aliases
        let aliases: [String] = {
            if let aliasArray = frontmatter["aliases"] as? [String] {
                return aliasArray
            } else if let aliasString = frontmatter["aliases"] as? String {
                let cleaned = aliasString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if cleaned.isEmpty { return [] }
                return cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return []
        }()

        // Extract body content after frontmatter
        let bodyContent: String = {
            let lines = content.components(separatedBy: .newlines)
            guard lines.count > 2, lines[0] == "---" else { return "" }

            var endIndex = -1
            for (index, line) in lines.enumerated() where index > 0 {
                if line == "---" {
                    endIndex = index
                    break
                }
            }

            guard endIndex > 0, endIndex + 1 < lines.count else { return "" }

            let bodyLines = Array(lines[(endIndex + 1)...])
            return bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        // Known field keys to exclude from unknownFields
        let knownKeys: Set<String> = [
            "type", "title", "creator", "release_year", "genre",
            "artwork_url", "itunes_id", "itunes_url", "tags", "aliases"
        ]

        // Collect unknown fields
        var unknownFields: [String: YAMLValue] = [:]
        var unknownFieldsOrder: [String] = []

        for (key, value) in frontmatter where !knownKeys.contains(key) {
            if let yamlValue = convertToYAMLValue(value) {
                unknownFields[key] = yamlValue
                unknownFieldsOrder.append(key)
            }
        }

        // Parse release_year
        let releaseYear: Int? = {
            if let year = frontmatter["release_year"] as? Int {
                return year
            } else if let yearString = frontmatter["release_year"] as? String,
                      let year = Int(yearString) {
                return year
            }
            return nil
        }()

        // Parse iTunes ID (might be stored as int or string)
        let iTunesID: String? = {
            if let id = frontmatter["itunes_id"] as? String {
                return id
            } else if let id = frontmatter["itunes_id"] as? Int {
                return String(id)
            }
            return nil
        }()

        return Media(
            id: name,
            title: title,
            mediaType: mediaType,
            creator: frontmatter["creator"] as? String,
            releaseYear: releaseYear,
            genre: frontmatter["genre"] as? String,
            artworkURL: frontmatter["artwork_url"] as? String,
            iTunesID: iTunesID,
            iTunesURL: frontmatter["itunes_url"] as? String,
            tags: tags,
            aliases: aliases,
            content: bodyContent,
            unknownFields: unknownFields,
            unknownFieldsOrder: unknownFieldsOrder
        )
    }

    /// Convert Any to YAMLValue
    nonisolated private static func convertToYAMLValue(_ value: Any) -> YAMLValue? {
        if let s = value as? String {
            return .string(s)
        } else if let i = value as? Int {
            return .int(i)
        } else if let d = value as? Double {
            return .double(d)
        } else if let b = value as? Bool {
            return .bool(b)
        } else if let arr = value as? [String] {
            return .array(arr)
        } else if let date = value as? Date {
            return .date(date)
        }
        return nil
    }

    /// Extract YAML frontmatter from markdown content
    nonisolated private static func extractFrontmatter(from content: String) -> [String: Any]? {
        let lines = content.components(separatedBy: .newlines)

        guard lines.count > 2, lines[0] == "---" else {
            return nil
        }

        var endIndex = -1
        for (index, line) in lines.enumerated() where index > 0 {
            if line == "---" {
                endIndex = index
                break
            }
        }

        guard endIndex > 0 else { return nil }

        let yamlLines = Array(lines[1..<endIndex])
        return parseYAMLLines(yamlLines)
    }

    /// Parse YAML lines into dictionary
    nonisolated private static func parseYAMLLines(_ lines: [String]) -> [String: Any] {
        var result: [String: Any] = [:]
        var currentKey: String?
        var arrayValues: [String] = []
        var inArray = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                // Array item
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                arrayValues.append(value)
                inArray = true
            } else if let colonIndex = trimmed.firstIndex(of: ":") {
                // Key-value pair

                // Save previous array if exists
                if inArray, let key = currentKey {
                    result[key] = arrayValues
                    arrayValues = []
                    inArray = false
                }

                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueString = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)

                currentKey = key

                if valueString.isEmpty {
                    // Array starts on next line or empty value
                    continue
                } else {
                    // Immediate value
                    result[key] = parseValue(valueString)
                }
            }
        }

        // Save final array if exists
        if inArray, let key = currentKey {
            result[key] = arrayValues
        }

        return result
    }

    /// Parse a YAML value (string, int, bool, etc.)
    nonisolated private static func parseValue(_ value: String) -> Any {
        var cleaned = value

        // Remove quotes
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Try to parse as Int
        if let intValue = Int(cleaned) {
            return intValue
        }

        // Try to parse as Double
        if let doubleValue = Double(cleaned) {
            return doubleValue
        }

        // Try to parse as Bool
        if cleaned.lowercased() == "true" { return true }
        if cleaned.lowercased() == "false" { return false }

        // Try to parse as Date (ISO 8601)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }

        // Return as String
        return cleaned
    }
}
