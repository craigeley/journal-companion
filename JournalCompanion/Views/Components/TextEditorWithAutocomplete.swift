//
//  TextEditorWithAutocomplete.swift
//  JournalCompanion
//
//  TextEditor with autocomplete support for wiki-links and mentions
//

import SwiftUI
import Combine

@MainActor
final class AutocompleteManager: ObservableObject {
    @Published var state = AutocompleteState()
    @Published var suggestions: [AutocompleteSuggestion] = []

    private let places: [Place]
    private let people: [Person]

    init(places: [Place], people: [Person]) {
        self.places = places
        self.people = people
    }

    /// Update autocomplete state based on current text
    func updateState(text: String) {
        // Find active trigger at end of text
        if let (trigger, searchText) = findActiveTrigger(in: text) {
            state.isActive = true
            state.trigger = trigger
            state.searchText = searchText

            // Filter suggestions
            suggestions = filterSuggestions(searchText: searchText, trigger: trigger)
        } else {
            state.isActive = false
            state.trigger = nil
            state.searchText = ""
            suggestions = []
        }
    }

    /// Find active trigger at cursor position (approximated as end of text)
    private func findActiveTrigger(in text: String) -> (AutocompleteTrigger, String)? {
        // Look for [[ trigger
        if let wikiLinkMatch = findTriggerMatch(in: text, trigger: .wikiLink) {
            return (.wikiLink, wikiLinkMatch)
        }

        // Look for @ trigger
        if let mentionMatch = findTriggerMatch(in: text, trigger: .mention) {
            return (.mention, mentionMatch)
        }

        return nil
    }

    /// Find trigger match and extract search text
    private func findTriggerMatch(in text: String, trigger: AutocompleteTrigger) -> String? {
        let pattern = trigger.pattern

        // Find last occurrence of trigger
        guard let lastTriggerRange = text.range(of: pattern, options: .backwards) else {
            return nil
        }

        // Get text after trigger
        let afterTrigger = String(text[lastTriggerRange.upperBound...])

        // Check if there's a closing delimiter that would end autocomplete
        let closingDelimiters: [Character] = trigger == .wikiLink ? ["]", "\n"] : [" ", "\n"]

        // If there's a closing delimiter before the end, autocomplete is not active
        if afterTrigger.contains(where: { closingDelimiters.contains($0) }) {
            return nil
        }

        // For wiki-links, don't activate if we already have complete [[...]]
        if trigger == .wikiLink {
            // Check if there's a complete wiki-link
            let afterText = String(text[lastTriggerRange.lowerBound...])
            if afterText.contains("]]") {
                return nil
            }
        }

        return afterTrigger.trimmingCharacters(in: .whitespaces)
    }

    /// Filter suggestions based on search text
    private func filterSuggestions(searchText: String, trigger: AutocompleteTrigger) -> [AutocompleteSuggestion] {
        let lowercasedSearch = searchText.lowercased()

        var results: [AutocompleteSuggestion] = []

        // For wiki-links, include both places and people
        // For mentions, only include people
        if trigger == .wikiLink || trigger == .mention {
            // Add people
            for person in people {
                if searchText.isEmpty {
                    results.append(.person(person, matchedAlias: nil))
                    continue
                }

                var didMatch = false

                // Check if any alias matches - add both alias and full name options
                if let matchedAlias = person.aliases.first(where: { $0.lowercased().contains(lowercasedSearch) }) {
                    // Add alias version first (preferred)
                    results.append(.person(person, matchedAlias: matchedAlias))
                    // Also add full name version as option
                    results.append(.person(person, matchedAlias: nil))
                    didMatch = true
                }

                // If no alias matched, check if name matches
                if !didMatch && person.name.lowercased().contains(lowercasedSearch) {
                    results.append(.person(person, matchedAlias: nil))
                }
            }
        }

        // Add places (only for wiki-links)
        if trigger == .wikiLink {
            for place in places {
                if searchText.isEmpty {
                    results.append(.place(place, matchedAlias: nil))
                    continue
                }

                var didMatch = false

                // Check if any alias matches - add both alias and full name options
                if let matchedAlias = place.aliases.first(where: { $0.lowercased().contains(lowercasedSearch) }) {
                    // Add alias version first (preferred)
                    results.append(.place(place, matchedAlias: matchedAlias))
                    // Also add full name version as option
                    results.append(.place(place, matchedAlias: nil))
                    didMatch = true
                }

                // If no alias matched, check if name matches
                if !didMatch && place.name.lowercased().contains(lowercasedSearch) {
                    results.append(.place(place, matchedAlias: nil))
                }
            }
        }

        // Sort by relevance (exact prefix matches first)
        return results.sorted { a, b in
            let aName = a.displayName.lowercased()
            let bName = b.displayName.lowercased()

            let aStartsWith = aName.hasPrefix(lowercasedSearch)
            let bStartsWith = bName.hasPrefix(lowercasedSearch)

            if aStartsWith != bStartsWith {
                return aStartsWith
            }

            return aName < bName
        }.prefix(10).map { $0 }
    }

    /// Insert selected suggestion into text
    /// Returns tuple of (newText, cursorPosition)
    func insertSuggestion(_ suggestion: AutocompleteSuggestion, into text: String) -> (String, Int) {
        guard let trigger = state.trigger else { return (text, text.count) }

        let pattern = trigger.pattern

        // Find last occurrence of trigger
        guard let lastTriggerRange = text.range(of: pattern, options: .backwards) else {
            return (text, text.count)
        }

        // Replace from trigger to end of text with insertion text
        let beforeTrigger = String(text[..<lastTriggerRange.lowerBound])
        let insertionText = suggestion.insertionText(for: trigger)

        // Add a space after insertion for better UX
        let newText = beforeTrigger + insertionText + " "

        // Calculate cursor position: after the closing ]] and space
        let cursorPosition = beforeTrigger.count + insertionText.count + 1

        return (newText, cursorPosition)
    }
}

struct TextEditorWithAutocomplete: View {
    @Binding var text: String
    @ObservedObject var autocompleteManager: AutocompleteManager
    let placeholder: String
    let minHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                // Text editor
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .onChange(of: text) { _, newValue in
                        autocompleteManager.updateState(text: newValue)
                    }
            }

            // Autocomplete suggestions
            if autocompleteManager.state.isActive && !autocompleteManager.suggestions.isEmpty {
                AutocompleteSuggestionView(suggestions: autocompleteManager.suggestions) { suggestion in
                    // Insert suggestion
                    let (newText, _) = autocompleteManager.insertSuggestion(suggestion, into: text)
                    text = newText
                    autocompleteManager.updateState(text: text)
                }
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: autocompleteManager.state.isActive)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @StateObject private var manager: AutocompleteManager

        private let places = [
            Place(id: "central-park", name: "Central Park", location: nil, address: "New York, NY", tags: [], callout: "park", pin: nil, color: nil, url: nil, aliases: [], content: ""),
            Place(id: "blue-bottle", name: "Blue Bottle Coffee", location: nil, address: "123 Main St", tags: [], callout: "cafe", pin: nil, color: nil, url: nil, aliases: ["BB"], content: "")
        ]

        private let people = [
            Person(id: "alice", name: "Alice Smith", pronouns: "she/her", relationshipType: .friend, tags: [], email: nil, phone: nil, address: nil, birthday: nil, metDate: nil, color: nil, photoFilename: nil, aliases: [], content: "")
        ]

        init() {
            _manager = StateObject(wrappedValue: AutocompleteManager(places: [], people: []))
        }

        var body: some View {
            VStack {
                TextEditorWithAutocomplete(
                    text: $text,
                    autocompleteManager: manager,
                    placeholder: "Type [[ or @ to autocomplete...",
                    minHeight: 120
                )
                .padding()

                Text("Current text: \(text)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                // Update manager with actual data after init
                manager.updateState(text: "")
            }
        }
    }

    return PreviewWrapper()
}
