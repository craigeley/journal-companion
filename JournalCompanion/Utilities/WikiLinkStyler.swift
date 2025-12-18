//
//  WikiLinkStyler.swift
//  JournalCompanion
//
//  Post-processes AttributedString to find and style wiki-links after markdown rendering
//

import Foundation
import SwiftUI

struct WikiLinkStyler {
    /// Post-process an AttributedString to find and style wiki-links
    /// This runs after markdown rendering, so wiki-links appear as literal [[...]] text
    static func styleWikiLinks(
        in attributedString: AttributedString,
        places: [Place],
        people: [Person]
    ) -> AttributedString {
        var result = attributedString
        let plainText = String(attributedString.characters)

        // Use WikiLinkParser to find all [[...]] patterns
        let wikiLinks = WikiLinkParser.parse(plainText, places: places, people: people)

        // Process in reverse to maintain indices as we modify the string
        for link in wikiLinks.reversed() {
            // Convert String.Index range to AttributedString.Index
            guard let attrRange = convertRange(link.range, in: result, plainText: plainText) else {
                continue
            }

            if link.isValid {
                // Valid link - add URL attribute and color
                let linkURL: URL
                let color: Color

                switch link.linkType {
                case .place:
                    guard let place = link.place else { continue }
                    linkURL = URL(string: "wikilink://place/\(place.id)")!
                    color = .blue
                case .person:
                    guard let person = link.person else { continue }
                    linkURL = URL(string: "wikilink://person/\(person.id)")!
                    color = .purple
                default:
                    continue
                }

                // Create replacement text (without brackets)
                var replacement = AttributedString(link.displayText)
                replacement.link = linkURL
                replacement.foregroundColor = color

                // Replace [[Name]] with styled Name
                result.replaceSubrange(attrRange, with: replacement)
            } else {
                // Invalid link - render as gray text without brackets
                var replacement = AttributedString(link.displayText)
                replacement.foregroundColor = .gray
                result.replaceSubrange(attrRange, with: replacement)
            }
        }

        return result
    }

    /// Convert a String.Index range to an AttributedString.Index range
    private static func convertRange(
        _ stringRange: Range<String.Index>,
        in attributed: AttributedString,
        plainText: String
    ) -> Range<AttributedString.Index>? {
        // Calculate UTF-16 offsets from the string
        let utf16Start = plainText.utf16.distance(from: plainText.startIndex, to: stringRange.lowerBound)
        let utf16End = plainText.utf16.distance(from: plainText.startIndex, to: stringRange.upperBound)

        // Convert to AttributedString indices
        let characters = Array(attributed.characters)

        guard utf16Start >= 0,
              utf16End <= characters.count,
              utf16Start < utf16End else {
            return nil
        }

        // Get the AttributedString.Index at these positions
        let startIndex = attributed.characters.index(attributed.characters.startIndex, offsetBy: utf16Start)
        let endIndex = attributed.characters.index(attributed.characters.startIndex, offsetBy: utf16End)

        return startIndex..<endIndex
    }
}
