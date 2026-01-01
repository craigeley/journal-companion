//
//  Person.swift
//  JournalCompanion
//
//  Core data model for people/relationships
//

import Foundation

struct Person: Identifiable, Codable, Sendable, Hashable {
    // Hashable conformance based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }

    let id: String  // Sanitized filename (without .md extension)
    var name: String
    var pronouns: String?
    var relationshipType: RelationshipType
    var tags: [String]
    var email: String?
    var phone: String?
    var address: String?
    var birthday: DateComponents?  // Month/day only (no year for privacy)
    var metDate: Date?
    var color: String?  // RGB format: rgb(72,133,237)
    var photoFilename: String?  // Filename in People/Photos/
    var aliases: [String]  // Alternative names for this person
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

    /// Sanitize address for YAML by replacing newlines with commas
    private func sanitizeAddressForYAML(_ address: String) -> String {
        // Replace newlines with comma-space
        let singleLine = address.replacingOccurrences(of: "\n", with: ", ")
        // Collapse multiple spaces
        let collapsed = singleLine.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespaces)
    }

    /// Convert person to markdown format with YAML frontmatter
    /// Uses template configuration to determine which fields to write
    func toMarkdown(template: PersonTemplate) -> String {
        var yaml = "---\n"

        // Get enabled fields sorted by order
        let enabledFields = template.fields
            .filter { $0.isEnabled }
            .sorted { $0.order < $1.order }

        for field in enabledFields {
            switch field.key {
            case "pronouns":
                if let pronouns = pronouns {
                    yaml += "pronouns: \(pronouns)\n"
                } else {
                    yaml += "pronouns:\n"  // Write empty field
                }

            case "relationship":
                yaml += "relationship: \(relationshipType.rawValue)\n"

            case "tags":
                if !tags.isEmpty {
                    yaml += "tags:\n"
                    for tag in tags {
                        yaml += "  - \(tag)\n"
                    }
                } else {
                    // Apply default tags from template if current tags empty
                    if case .tags(let defaultTags) = field.defaultValue, !defaultTags.isEmpty {
                        yaml += "tags:\n"
                        for tag in defaultTags {
                            yaml += "  - \(tag)\n"
                        }
                    } else {
                        yaml += "tags:\n"  // Empty array
                    }
                }

            case "email":
                if let email = email {
                    yaml += "email: \(email)\n"
                } else {
                    yaml += "email:\n"
                }

            case "phone":
                if let phone = phone {
                    yaml += "phone: \(phone)\n"
                } else {
                    yaml += "phone:\n"
                }

            case "address":
                if let address = address {
                    let sanitized = sanitizeAddressForYAML(address)
                    yaml += "address: \(sanitized)\n"
                } else {
                    yaml += "address:\n"
                }

            case "birthday":
                if let birthday = birthday, let month = birthday.month, let day = birthday.day {
                    if let year = birthday.year {
                        yaml += String(format: "birthday: %04d-%02d-%02d\n", year, month, day)
                    } else {
                        yaml += String(format: "birthday: %02d-%02d\n", month, day)
                    }
                } else {
                    yaml += "birthday:\n"
                }

            case "met_date":
                if let metDate = metDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    yaml += "met_date: \(formatter.string(from: metDate))\n"
                } else {
                    yaml += "met_date:\n"
                }

            case "color":
                if let color = color {
                    yaml += "color: \(color)\n"
                } else {
                    yaml += "color:\n"
                }

            case "photo":
                if let photoFilename = photoFilename {
                    yaml += "photo: \(photoFilename)\n"
                } else {
                    yaml += "photo:\n"
                }

            case "aliases":
                if !aliases.isEmpty {
                    yaml += "aliases:\n"
                    for alias in aliases {
                        yaml += "  - \(alias)\n"
                    }
                } else {
                    yaml += "aliases: []\n"
                }

            default:
                break
            }
        }

        yaml += "---\n\n"

        return yaml + content
    }

    /// Legacy method for backwards compatibility
    func toMarkdown() -> String {
        toMarkdown(template: .defaultTemplate)
    }

    /// Parse Person from markdown file content
    nonisolated static func parse(from content: String, filename: String) -> Person? {
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }

        let name = String(filename.dropLast(3))  // Remove .md extension

        // Parse birthday (supports both MM-DD and YYYY-MM-DD formats, stores year if available)
        let birthday: DateComponents? = {
            guard let birthdayString = frontmatter["birthday"] as? String else { return nil }
            let components = birthdayString.split(separator: "-")

            var year: Int?
            var month: Int?
            var day: Int?

            if components.count == 2 {
                // MM-DD format (legacy, no year)
                month = Int(components[0])
                day = Int(components[1])
            } else if components.count == 3 {
                // YYYY-MM-DD format (ISO 8601) - store all components including year
                year = Int(components[0])
                month = Int(components[1])
                day = Int(components[2])
            }

            guard let month = month, let day = day else {
                return nil
            }

            var dateComponents = DateComponents()
            dateComponents.year = year  // Store year if available
            dateComponents.month = month
            dateComponents.day = day
            return dateComponents
        }()

        // Parse met_date
        let metDate: Date? = {
            guard let dateString = frontmatter["met_date"] as? String else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }()

        // Extract tags
        let tags: [String] = {
            if let tagArray = frontmatter["tags"] as? [String] {
                return tagArray
            } else if let tagString = frontmatter["tags"] as? String {
                // Handle inline format: [tag1, tag2]
                let cleaned = tagString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if cleaned.isEmpty { return [] }
                return cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return []
        }()

        // Extract aliases
        let aliases: [String] = {
            if let aliasArray = frontmatter["aliases"] as? [String] {
                return aliasArray
            } else if let aliasString = frontmatter["aliases"] as? String {
                // Handle inline format: [alias1, alias2]
                let cleaned = aliasString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if cleaned.isEmpty { return [] }
                return cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return []
        }()

        // Extract relationship type
        let relationshipType: RelationshipType = {
            guard let typeString = frontmatter["relationship"] as? String,
                  let type = RelationshipType(rawValue: typeString) else {
                return .other
            }
            return type
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

        return Person(
            id: name,
            name: name,
            pronouns: frontmatter["pronouns"] as? String,
            relationshipType: relationshipType,
            tags: tags,
            email: frontmatter["email"] as? String,
            phone: frontmatter["phone"] as? String,
            address: frontmatter["address"] as? String,
            birthday: birthday,
            metDate: metDate,
            color: frontmatter["color"] as? String,
            photoFilename: frontmatter["photo"] as? String,
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

enum RelationshipType: String, Codable, CaseIterable, Sendable {
    case family
    case friend
    case colleague
    case acquaintance
    case partner
    case mentor
    case other
}
