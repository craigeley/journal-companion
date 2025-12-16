//
//  WikiText.swift
//  JournalCompanion
//
//  Reusable SwiftUI component for rendering text with wiki-links
//

import SwiftUI

struct WikiText: View {
    let text: String
    let places: [Place]
    let lineLimit: Int?
    let font: Font

    @EnvironmentObject var vaultManager: VaultManager
    @State private var selectedPlace: Place?

    init(
        text: String,
        places: [Place],
        lineLimit: Int? = nil,
        font: Font = .body
    ) {
        self.text = text
        self.places = places
        self.lineLimit = lineLimit
        self.font = font
    }

    var body: some View {
        Text(attributedString)
            .font(font)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                handleLinkTap(url: url)
                return .handled
            })
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
                    .environmentObject(vaultManager)
            }
    }

    private var attributedString: AttributedString {
        let links = WikiLinkParser.parse(text, places: places)

        guard !links.isEmpty else {
            return AttributedString(text)
        }

        var result = AttributedString()
        var currentIndex = text.startIndex

        for link in links {
            // Add text before link
            if currentIndex < link.range.lowerBound {
                let segment = String(text[currentIndex..<link.range.lowerBound])
                result += AttributedString(segment)
            }

            // Add styled link (without brackets, using displayText)
            var linkText = AttributedString(link.displayText)

            if link.isValid {
                // Blue, tappable link
                linkText.foregroundColor = .blue
                linkText.link = URL(string: "app://place/\(link.place!.id)")
            } else {
                // Gray, non-tappable text
                linkText.foregroundColor = .secondary
            }

            result += linkText
            currentIndex = link.range.upperBound
        }

        // Add remaining text after last link
        if currentIndex < text.endIndex {
            let segment = String(text[currentIndex...])
            result += AttributedString(segment)
        }

        return result
    }

    private func handleLinkTap(url: URL) {
        guard url.scheme == "app",
              url.host == "place",
              let placeId = url.pathComponents.last else {
            return
        }

        selectedPlace = places.first { $0.id == placeId }
    }
}
