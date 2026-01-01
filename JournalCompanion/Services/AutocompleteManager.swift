//
//  AutocompleteManager.swift
//  JournalCompanion
//
//  Manages autocomplete state and suggestions for wiki-links and mentions
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
