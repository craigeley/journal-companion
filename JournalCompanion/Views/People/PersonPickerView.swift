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
