//
//  EntryDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying entry information (read-only)
//

import SwiftUI

struct EntryDetailView: View {
    let entry: Entry
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    @State private var showEditView = false
    @State private var selectedPlace: Place?
    @State private var selectedPerson: Person?

    var body: some View {
        NavigationStack {
            List {
                // Entry Content Section (read-only)
                Section("Entry") {
                    Text(entry.content)
                        .font(.body)
                }

                // Location Section
                if let placeName = entry.place {
                    Section("Location") {
                        if let place = vaultManager.places.first(where: { $0.name == placeName }) {
                            HStack {
                                Image(systemName: PlaceIcon.systemName(for: place.callout))
                                    .foregroundStyle(PlaceIcon.color(for: place.callout))
                                Text(place.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlace = place
                            }
                        } else {
                            Text(placeName)
                        }
                    }
                }

                // People Section
                if !entry.people.isEmpty {
                    Section("People") {
                        ForEach(entry.people, id: \.self) { personName in
                            if let person = vaultManager.people.first(where: { $0.name == personName }) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.purple)
                                    Text(person.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPerson = person
                                }
                            } else {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(.purple)
                                    Text(personName)
                                }
                            }
                        }
                    }
                }

                // Details Section
                Section("Details") {
                    LabeledContent("Date") {
                        Text(entry.dateCreated, style: .date)
                    }
                    LabeledContent("Time") {
                        Text(entry.dateCreated, style: .time)
                    }

                    if !entry.tags.isEmpty {
                        LabeledContent("Tags") {
                            Text(entry.tags.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                }

                // Weather Section (if exists)
                if entry.temperature != nil || entry.condition != nil {
                    Section("Weather") {
                        if let temp = entry.temperature {
                            LabeledContent("Temperature", value: "\(temp)°F")
                        }
                        if let condition = entry.condition {
                            LabeledContent("Condition", value: condition)
                        }
                        if let humidity = entry.humidity {
                            LabeledContent("Humidity", value: "\(humidity)%")
                        }
                        if let aqi = entry.aqi {
                            LabeledContent("AQI", value: "\(aqi)")
                        }
                    }
                }
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showEditView = true
                    }
                }
            }
            .sheet(isPresented: $showEditView) {
                EntryEditView(viewModel: EntryEditViewModel(
                    entry: entry,
                    vaultManager: vaultManager,
                    locationService: LocationService()
                ))
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
                    .environmentObject(vaultManager)
            }
            .sheet(item: $selectedPerson) { person in
                PersonDetailView(person: person)
                    .environmentObject(vaultManager)
            }
        }
    }
}
