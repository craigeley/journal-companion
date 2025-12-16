//
//  PersonRow.swift
//  JournalCompanion
//
//  Reusable row component for displaying person information
//

import SwiftUI

struct PersonRow: View {
    let person: Person
    let isSelected: Bool

    init(person: Person, isSelected: Bool = false) {
        self.person = person
        self.isSelected = isSelected
    }

    var body: some View {
        HStack {
            // Icon (person silhouette with relationship color)
            Image(systemName: "person.circle.fill")
                .foregroundStyle(colorForRelationship(person.relationshipType))
                .frame(width: 32)

            // Person info
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)

                HStack(spacing: 4) {
                    Text(person.relationshipType.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let pronouns = person.pronouns {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(pronouns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Show tags if not empty
                if !person.tags.isEmpty {
                    Text(person.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Checkmark for multi-select (optional)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForRelationship(_ type: RelationshipType) -> Color {
        switch type {
        case .family: return .red
        case .friend: return .blue
        case .colleague: return .green
        case .acquaintance: return .gray
        case .partner: return .pink
        case .mentor: return .purple
        case .other: return .orange
        }
    }
}
