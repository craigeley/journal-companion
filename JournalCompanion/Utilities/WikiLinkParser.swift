//
//  WikiLinkParser.swift
//  JournalCompanion
//
//  Utility for parsing and validating Obsidian wiki-link syntax
//

import Foundation

enum WikiLinkType {
    case place
    case person
    case unknown
}

struct WikiLink: Identifiable {
    let id = UUID()
    let target: String                  // Target name for matching (e.g., "Willy St Co-Op" or "Alice Smith")
    let displayText: String             // Text to display (e.g., "co-op" or "Alice")
    let range: Range<String.Index>      // Position in original text
    let linkType: WikiLinkType          // Type of link (place, person, or unknown)
    let isValid: Bool                   // Whether place or person exists
    let place: Place?                   // Resolved place if valid
    let person: Person?                 // Resolved person if valid
}

struct WikiLinkParser {
    /// Parse wiki-links from text and validate against places and people
    static func parse(_ text: String, places: [Place], people: [Person]) -> [WikiLink] {
        let links = extractLinks(text)
        return links.map { (target, displayText, range) in
            // Try to match as place first
            if let matchedPlace = findPlace(named: target, in: places) {
                return WikiLink(
                    target: target,
                    displayText: displayText,
                    range: range,
                    linkType: .place,
                    isValid: true,
                    place: matchedPlace,
                    person: nil
                )
            }

            // Try to match as person
            if let matchedPerson = findPerson(named: target, in: people) {
                return WikiLink(
                    target: target,
                    displayText: displayText,
                    range: range,
                    linkType: .person,
                    isValid: true,
                    place: nil,
                    person: matchedPerson
                )
            }

            // No match found
            return WikiLink(
                target: target,
                displayText: displayText,
                range: range,
                linkType: .unknown,
                isValid: false,
                place: nil,
                person: nil
            )
        }
    }

    /// Extract all [[...]] patterns from text
    /// Returns tuples of (target, displayText, range)
    /// Handles both [[target]] and [[target|display]] formats
    private static func extractLinks(_ text: String) -> [(target: String, displayText: String, range: Range<String.Index>)] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range(at: 0), in: text),
                  let contentRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            let content = String(text[contentRange])

            // Check for pipe syntax: [[target|display]]
            if let pipeIndex = content.firstIndex(of: "|") {
                let target = String(content[..<pipeIndex]).trimmingCharacters(in: .whitespaces)
                let display = String(content[content.index(after: pipeIndex)...]).trimmingCharacters(in: .whitespaces)
                return (target, display, fullRange)
            } else {
                // No pipe, use same text for both target and display
                return (content, content, fullRange)
            }
        }
    }

    /// Find place by name or alias (case-insensitive)
    private static func findPlace(named name: String, in places: [Place]) -> Place? {
        let lowercasedName = name.lowercased()

        // Match against place.name
        if let match = places.first(where: { $0.name.lowercased() == lowercasedName }) {
            return match
        }

        // Match against place.aliases
        return places.first(where: { place in
            place.aliases.contains(where: { $0.lowercased() == lowercasedName })
        })
    }

    /// Find person by name (case-insensitive)
    private static func findPerson(named name: String, in people: [Person]) -> Person? {
        let lowercasedName = name.lowercased()
        return people.first { $0.name.lowercased() == lowercasedName }
    }
}
