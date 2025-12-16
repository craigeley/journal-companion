//
//  PersonPickerView.swift
//  JournalCompanion
//
//  Multi-select picker for linking people to entries
//

import SwiftUI

struct PersonPickerView: View {
    let people: [Person]
    @Binding var selectedPeople: [String]  // Array of person names
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { person in
            person.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredPeople.isEmpty {
                    ContentUnavailableView {
                        Label("No People Found", systemImage: "person.slash")
                    } description: {
                        Text("Try adjusting your search or create a new person")
                    }
                } else {
                    Section(searchText.isEmpty ? "All People" : "Search Results") {
                        ForEach(filteredPeople) { person in
                            PersonRow(
                                person: person,
                                isSelected: selectedPeople.contains(person.name)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(person: person)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("Select People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleSelection(person: Person) {
        if let index = selectedPeople.firstIndex(of: person.name) {
            selectedPeople.remove(at: index)
        } else {
            selectedPeople.append(person.name)
        }
    }
}

// MARK: - Person Row
struct PersonRow: View {
    let person: Person
    let isSelected: Bool

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
            }

            Spacer()

            // Checkmark for multi-select
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
