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
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @Environment(\.dismiss) var dismiss
    @State private var showEditView = false

    var body: some View {
        NavigationStack {
            List {
                // Entry Content Section (read-only with rendered wiki-links)
                Section("Entry") {
                    WikiText(
                        text: entry.content,
                        places: vaultManager.places,
                        people: vaultManager.people,
                        lineLimit: nil,
                        font: .body
                    )
                }

                // Location Section (place wiki-links in content are also tappable)
                if let placeName = entry.place {
                    Section("Location") {
                        if let place = vaultManager.places.first(where: { $0.name == placeName }) {
                            Text(place.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(placeName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // People Section removed - people now rendered inline as wiki-links in entry content

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
                    locationService: locationService
                ))
            }
        }
    }
}
