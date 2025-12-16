//
//  WikiLinkParser.swift
//  JournalCompanion
//
//  Utility for parsing and validating Obsidian wiki-link syntax
//

import Foundation

struct WikiLink: Identifiable {
    let id = UUID()
    let target: String                  // Target name for matching (e.g., "Willy St Co-Op")
    let displayText: String             // Text to display (e.g., "co-op")
    let range: Range<String.Index>      // Position in original text
    let isValid: Bool                   // Whether place exists
    let place: Place?                   // Resolved place if valid
}

struct WikiLinkParser {
    /// Parse wiki-links from text and validate against places
    static func parse(_ text: String, places: [Place]) -> [WikiLink] {
        let links = extractLinks(text)
        return links.map { (target, displayText, range) in
            let matchedPlace = findPlace(named: target, in: places)
            return WikiLink(
                target: target,
                displayText: displayText,
                range: range,
                isValid: matchedPlace != nil,
                place: matchedPlace
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
}
