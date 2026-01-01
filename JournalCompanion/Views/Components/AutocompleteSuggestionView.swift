//
//  AutocompleteSuggestionView.swift
//  JournalCompanion
//
//  Displays autocomplete suggestions for wiki-links and mentions
//

import SwiftUI

struct AutocompleteSuggestionView: View {
    let suggestions: [AutocompleteSuggestion]
    let onSelect: (AutocompleteSuggestion) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            // Icon
                            Image(systemName: suggestion.iconName)
                                .foregroundStyle(PlaceIcon.color(for: suggestion.iconColor))
                                .font(.title3)
                                .frame(width: 30)

                            // Text content
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if let subtitle = suggestion.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

// MARK: - Preview
#Preview {
    let place1 = Place(
        id: "central-park",
        name: "Central Park",
        location: nil,
        address: "New York, NY",
        tags: [],
        callout: .park,
        pin: nil,
        color: nil,
        url: nil,
        aliases: [],
        content: ""
    )

    let place2 = Place(
        id: "blue-bottle",
        name: "Blue Bottle Coffee",
        location: nil,
        address: "123 Main St",
        tags: [],
        callout: .cafe,
        pin: nil,
        color: nil,
        url: nil,
        aliases: ["BB Coffee"],
        content: ""
    )

    let person1 = Person(
        id: "alice-smith",
        name: "Alice Smith",
        pronouns: "she/her",
        relationshipType: .friend,
        tags: [],
        email: nil,
        phone: nil,
        address: nil,
        birthday: nil,
        metDate: nil,
        color: nil,
        photoFilename: nil,
        aliases: [],
        content: ""
    )

    let suggestions: [AutocompleteSuggestion] = [
        .place(place1, matchedAlias: nil),
        .place(place2, matchedAlias: "BB Coffee"),
        .person(person1, matchedAlias: nil)
    ]

    return VStack {
        Spacer()
        AutocompleteSuggestionView(suggestions: suggestions) { suggestion in
            print("Selected: \(suggestion.displayName)")
        }
        .padding()
    }
}
