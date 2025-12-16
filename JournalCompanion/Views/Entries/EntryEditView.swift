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
    @State private var showPlaceDetails = false
    @State private var showPersonPicker = false
    @State private var selectedPersonForDetail: Person?

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
                            // Tappable area for place name/icon
                            HStack {
                                Image(systemName: PlaceIcon.systemName(for: place.callout))
                                    .foregroundStyle(PlaceIcon.color(for: place.callout))
                                Text(place.name)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showPlaceDetails = true
                            }

                            Spacer()

                            // Keep existing "Change" button
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

                // People Section
                Section("People") {
                    Button {
                        showPersonPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.purple)
                            if viewModel.selectedPeople.isEmpty {
                                Text("Select People")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(viewModel.selectedPeople.count) selected")
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }

                    // People chips (if any selected)
                    if !viewModel.selectedPeople.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.selectedPeople, id: \.self) { personName in
                                PersonChip(
                                    name: personName,
                                    onTap: {
                                        // Find person and show detail
                                        selectedPersonForDetail = viewModel.vaultManager.people.first { $0.name == personName }
                                    },
                                    onDelete: {
                                        viewModel.selectedPeople.removeAll { $0 == personName }
                                    }
                                )
                            }
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
                    Section {
                        if let temp = viewModel.temperature {
                            HStack {
                                Text("Temperature")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(temp)°F")
                            }
                        }
                        if let condition = viewModel.condition {
                            HStack {
                                Text("Condition")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(condition)
                            }
                        }
                        if let humidity = viewModel.humidity {
                            HStack {
                                Text("Humidity")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(humidity)%")
                            }
                        }
                        if let aqi = viewModel.aqi {
                            HStack {
                                Text("AQI")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(aqi)")
                            }
                        }

                        // Show refresh button if weather is stale
                        if viewModel.weatherIsStale {
                            Button {
                                Task {
                                    await viewModel.refreshWeather()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh Weather")
                                    Spacer()
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    } header: {
                        Text("Weather")
                    } footer: {
                        if viewModel.weatherIsStale {
                            Text("Date or location changed. Tap to refresh weather.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } else if viewModel.isFetchingWeather {
                    Section("Weather") {
                        HStack {
                            ProgressView()
                            Text("Fetching weather...")
                                .foregroundStyle(.secondary)
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
            .sheet(isPresented: $showPersonPicker) {
                PersonPickerView(
                    people: viewModel.vaultManager.people,
                    selectedPeople: $viewModel.selectedPeople
                )
            }
            .sheet(item: $selectedPersonForDetail) { person in
                PersonDetailView(person: person)
                    .environmentObject(viewModel.vaultManager)
            }
            .sheet(isPresented: $showPlaceDetails) {
                if let place = viewModel.selectedPlace {
                    PlaceDetailView(place: place)
                        .environmentObject(viewModel.vaultManager)
                }
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
            .alert("Move Entry File?", isPresented: $viewModel.showDateChangeWarning) {
                Button("Cancel", role: .cancel) {
                    // Just dismiss - don't save
                }
                Button("Save") {
                    Task {
                        await viewModel.confirmDateChange()
                        if viewModel.saveError == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Changing the date will move this entry to a different day file. Continue?")
            }
        }
    }
}
