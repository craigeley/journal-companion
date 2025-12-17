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
    let people: [Person]
    let lineLimit: Int?
    let font: Font

    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @State private var selectedPlace: Place?
    @State private var selectedPerson: Person?

    init(
        text: String,
        places: [Place],
        people: [Person] = [],
        lineLimit: Int? = nil,
        font: Font = .body
    ) {
        self.text = text
        self.places = places
        self.people = people
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
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            }
            .sheet(item: $selectedPerson) { person in
                PersonDetailView(person: person)
                    .environmentObject(vaultManager)
            }
    }

    private var attributedString: AttributedString {
        let links = WikiLinkParser.parse(text, places: places, people: people)

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
                switch link.linkType {
                case .place:
                    // Blue, tappable place link
                    linkText.foregroundColor = .blue
                    linkText.link = URL(string: "app://place/\(link.place!.id)")
                case .person:
                    // Purple, tappable person link
                    linkText.foregroundColor = .purple
                    linkText.link = URL(string: "app://person/\(link.person!.id)")
                case .unknown:
                    // Gray, non-tappable text
                    linkText.foregroundColor = .secondary
                }
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
        guard url.scheme == "app" else { return }

        switch url.host {
        case "place":
            guard let placeId = url.pathComponents.last else { return }
            selectedPlace = places.first { $0.id == placeId }

        case "person":
            guard let personId = url.pathComponents.last else { return }
            selectedPerson = people.first { $0.id == personId }

        default:
            return
        }
    }
}
