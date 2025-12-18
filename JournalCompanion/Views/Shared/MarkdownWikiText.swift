//
//  MarkdownWikiText.swift
//  JournalCompanion
//
//  Renders markdown + wiki-links using Foundation AttributedString
//  Renders markdown first, then post-processes to style wiki-links
//

import SwiftUI

struct MarkdownWikiText: View {
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
        Text(styledAttributedString)
            .font(font)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                handleWikiLink(url: url)
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

    private var styledAttributedString: AttributedString {
        // Phase 1: Render markdown with Foundation
        // This treats [[...]] as literal text (doesn't understand wiki-link syntax)
        var attributed: AttributedString
        if let markdownResult = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            attributed = markdownResult
        } else {
            // Fallback to plain text if markdown parsing fails
            attributed = AttributedString(text)
        }

        // Phase 2: Post-process to find and style wiki-links
        // Find [[...]] patterns, validate them, apply colors, make tappable, remove brackets
        return WikiLinkStyler.styleWikiLinks(
            in: attributed,
            places: places,
            people: people
        )
    }

    private func handleWikiLink(url: URL) {
        guard url.scheme == "wikilink" else { return }

        switch url.host {
        case "place":
            let id = url.lastPathComponent
            selectedPlace = places.first { $0.id == id }
        case "person":
            let id = url.lastPathComponent
            selectedPerson = people.first { $0.id == id }
        default:
            break
        }
    }
}
