//
//  Place.swift
//  JournalCompanion
//
//  Core data model for places/locations
//

import Foundation
import CoreLocation

struct Place: Identifiable, Codable, Sendable {
    let id: String  // Sanitized filename (without .md extension)
    var name: String
    var location: CLLocationCoordinate2D?
    var address: String?
    var tags: [String]
    var callout: String  // school, park, cafe, restaurant, etc.
    var pin: String?  // SF Symbol name
    var color: String?  // RGB format: rgb(72,133,237)
    var url: String?
    var aliases: [String]
    var content: String  // Body text after YAML frontmatter

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

    /// Convert place to markdown format with YAML frontmatter
    func toMarkdown() -> String {
        var yaml = "---\n"

        if let loc = location {
            yaml += "location: \(loc.latitude),\(loc.longitude)\n"
        }
        if let addr = address {
            yaml += "addr: \(addr)\n"
        }

        yaml += "tags: \(tags)\n"
        yaml += "callout: \(callout)\n"

        if let pin = pin {
            yaml += "pin: \(pin)\n"
        }
        if let color = color {
            yaml += "color: \(color)\n"
        }
        if let url = url {
            yaml += "url: \(url)\n"
        }

        yaml += "aliases: \(aliases)\n"
        yaml += "---\n\n"

        return yaml + content
    }

    /// Parse Place from markdown file content
    nonisolated static func parse(from content: String, filename: String) -> Place? {
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }

        let name = String(filename.dropLast(3))  // Remove .md extension

        // Parse location coordinates
        let location: CLLocationCoordinate2D? = {
            guard let locString = frontmatter["location"] as? String else { return nil }
            let coords = locString.split(separator: ",")
            guard coords.count == 2,
                  let lat = Double(coords[0].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(coords[1].trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()

        // Extract tags
        let tags: [String] = {
            if let tagArray = frontmatter["tags"] as? [String] {
                return tagArray
            } else if let tagString = frontmatter["tags"] as? String {
                // Handle inline format: [tag1, tag2]
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

            // Find closing ---
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

        return Place(
            id: name,
            name: name,
            location: location,
            address: frontmatter["addr"] as? String,
            tags: tags,
            callout: frontmatter["callout"] as? String ?? "place",
            pin: frontmatter["pin"] as? String,
            color: frontmatter["color"] as? String,
            url: frontmatter["url"] as? String,
            aliases: aliases,
            content: bodyContent
        )
    }

    /// Extract YAML frontmatter from markdown content
    nonisolated private static func extractFrontmatter(from content: String) -> [String: Any]? {
        let lines = content.components(separatedBy: .newlines)

        guard lines.count > 2, lines[0] == "---" else {
            return nil
        }

        // Find closing ---
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

// MARK: - CLLocationCoordinate2D Codable
// Note: CLLocationCoordinate2D will gain Codable conformance in future iOS versions
// For now, we handle encoding/decoding in Place's custom Codable implementation
extension CLLocationCoordinate2D: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}
