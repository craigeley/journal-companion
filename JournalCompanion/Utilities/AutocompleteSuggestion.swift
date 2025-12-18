//
//  AutocompleteSuggestion.swift
//  JournalCompanion
//
//  Model for autocomplete suggestions
//

import Foundation

enum AutocompleteTrigger {
    case wikiLink  // [[
    case mention   // @

    var pattern: String {
        switch self {
        case .wikiLink: return "[["
        case .mention: return "@"
        }
    }
}

enum AutocompleteSuggestion: Identifiable {
    case place(Place, matchedAlias: String?)
    case person(Person, matchedAlias: String?)

    var id: String {
        switch self {
        case .place(let place, let alias):
            if let alias = alias {
                return "place-\(place.id)-alias-\(alias)"
            }
            return "place-\(place.id)"
        case .person(let person, let alias):
            if let alias = alias {
                return "person-\(person.id)-alias-\(alias)"
            }
            return "person-\(person.id)"
        }
    }

    var displayName: String {
        switch self {
        case .place(let place, _): return place.name
        case .person(let person, _): return person.name
        }
    }

    var matchedAlias: String? {
        switch self {
        case .place(_, let alias): return alias
        case .person(_, let alias): return alias
        }
    }

    var iconName: String {
        switch self {
        case .place(let place, _): return PlaceIcon.systemName(for: place.callout)
        case .person: return "person.circle.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .place(let place, _): return place.callout
        case .person: return "purple"
        }
    }

    var subtitle: String? {
        switch self {
        case .place(let place, let alias):
            if let alias = alias {
                return "as: \(alias)"
            }
            return place.address
        case .person(let person, let alias):
            if let alias = alias {
                return "as: \(alias)"
            }
            return person.relationshipType.rawValue.capitalized
        }
    }

    var aliases: [String] {
        switch self {
        case .place(let place, _): return place.aliases
        case .person(let person, _): return person.aliases
        }
    }

    /// Get the text to insert when this suggestion is selected
    func insertionText(for trigger: AutocompleteTrigger) -> String {
        let baseText: String

        // Use pipe syntax if an alias was matched: [[Full Name|alias]]
        if let alias = matchedAlias {
            baseText = "[[\(displayName)|\(alias)]]"
        } else {
            baseText = "[[\(displayName)]]"
        }

        return baseText
    }
}

struct AutocompleteState {
    var isActive: Bool = false
    var trigger: AutocompleteTrigger?
    var searchText: String = ""
    var triggerRange: Range<String.Index>?
    var cursorPosition: Int = 0
}
