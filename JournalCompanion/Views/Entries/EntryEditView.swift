//
//  EntryEditView.swift
//  JournalCompanion
//
//  Edit screen for existing journal entries
//

import SwiftUI

struct EntryEditView: View {
    @StateObject var viewModel: EntryEditViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showPlacePicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Entry Content Section
                Section("Entry") {
                    TextEditor(text: $viewModel.entryText)
                        .frame(minHeight: 200)
                        .font(.body)
                }

                // Location Section
                Section("Location") {
                    if let place = viewModel.selectedPlace {
                        HStack {
                            Image(systemName: PlaceIcon.systemName(for: place.callout))
                                .foregroundStyle(PlaceIcon.color(for: place.callout))
                            Text(place.name)
                            Spacer()
                            Button("Change") {
                                showPlacePicker = true
                            }
                            .font(.caption)
                        }
                    } else {
                        Button("Add Location") {
                            showPlacePicker = true
                        }
                    }
                }

                // Details Section
                Section("Details") {
                    DatePicker("Timestamp", selection: $viewModel.timestamp)

                    // Tags (simple comma-separated for now)
                    Text("Tags: \(viewModel.tags.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Weather Section (if exists)
                if viewModel.temperature != nil || viewModel.condition != nil {
                    Section("Weather") {
                        if let temp = viewModel.temperature {
                            Text("Temperature: \(temp)°")
                        }
                        if let condition = viewModel.condition {
                            Text("Condition: \(condition)")
                        }
                        if let aqi = viewModel.aqi {
                            Text("AQI: \(aqi)")
                        }
                        if let humidity = viewModel.humidity {
                            Text("Humidity: \(humidity)%")
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.saveChanges() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.entryText.isEmpty)
                }
            }
            .sheet(isPresented: $showPlacePicker) {
                PlacePickerView(
                    places: viewModel.vaultManager.places,
                    currentLocation: viewModel.currentLocation,
                    selectedPlace: $viewModel.selectedPlace
                )
            }
            .task {
                await viewModel.detectCurrentLocation()
            }
            .alert("Save Error", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") {
                    viewModel.saveError = nil
                }
            } message: {
                if let error = viewModel.saveError {
                    Text(error)
                }
            }
        }
    }
}
