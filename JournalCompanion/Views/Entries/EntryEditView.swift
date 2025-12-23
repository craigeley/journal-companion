//
//  EntryEditView.swift
//  JournalCompanion
//
//  Edit screen for existing journal entries
//

import SwiftUI
import MapKit
import CoreLocation

struct EntryEditView: View {
    @StateObject var viewModel: EntryEditViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showPlacePicker = false
    @State private var showPlaceDetails = false
    @State private var showAddTag = false
    @State private var newTag = ""

    // Place creation flow state
    @State private var showLocationSearchForNewPlace = false
    @State private var showPlaceCreationFromPicker = false
    @State private var pendingLocationName: String?
    @State private var pendingAddress: String?
    @State private var pendingCoordinates: CLLocationCoordinate2D?
    @State private var pendingURL: String?
    @State private var pendingPOICategory: MKPointOfInterestCategory?
    @State private var createPlaceRequested = false
    @State private var searchNearbyRequested = false

    var body: some View {
        NavigationStack {
            Form {
                // Entry Content Section
                Section {
                    if viewModel.isAudioEntry {
                        // Audio entries: content is read-only (mirrored from SRT)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.entryText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)

                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("This is an audio entry. Edit transcripts in entry details.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        // Regular entries: content is editable
                        SmartTextEditor(
                            text: $viewModel.entryText,
                            places: viewModel.vaultManager.places,
                            people: viewModel.vaultManager.people,
                            minHeight: 200
                        )
                        .font(.body)
                    }
                } header: {
                    Text("Entry")
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

                // Details Section
                Section("Details") {
                    DatePicker("Timestamp", selection: $viewModel.timestamp)
                }

                // Tags Section
                Section("Tags") {
                    ForEach(viewModel.tags.indices, id: \.self) { index in
                        HStack {
                            Text(viewModel.tags[index])
                            Spacer()
                            Button(action: {
                                viewModel.tags.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button("Add Tag") {
                        showAddTag = true
                    }
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
                } else {
                    // No weather data - offer to add it
                    Section {
                        Button {
                            Task {
                                await viewModel.detectCurrentLocation()
                                await viewModel.refreshWeather()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "cloud.sun")
                                    .foregroundStyle(.blue)
                                Text("Add Weather")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Weather")
                    } footer: {
                        Text("Fetch weather data for this entry's date and location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    selectedPlace: $viewModel.selectedPlace,
                    onCreatePlaceRequested: $createPlaceRequested,
                    onSearchNearbyRequested: $searchNearbyRequested
                )
            }
            .onChange(of: showPlacePicker) { oldValue, newValue in
                if !newValue {
                    // PlacePickerView dismissed
                    if createPlaceRequested || searchNearbyRequested {
                        showLocationSearchForNewPlace = true
                    }
                }
            }
            .sheet(isPresented: $showLocationSearchForNewPlace) {
                LocationSearchView(
                    selectedLocationName: $pendingLocationName,
                    selectedAddress: $pendingAddress,
                    selectedCoordinates: $pendingCoordinates,
                    selectedURL: $pendingURL,
                    selectedPOICategory: $pendingPOICategory
                )
            }
            .onChange(of: showLocationSearchForNewPlace) { oldValue, newValue in
                if !newValue {
                    // LocationSearchView dismissed
                    if pendingLocationName != nil {
                        // Location was selected, show PlaceEditView
                        showPlaceCreationFromPicker = true
                    } else {
                        // User cancelled, reset flags
                        createPlaceRequested = false
                        searchNearbyRequested = false
                    }
                }
            }
            .sheet(isPresented: $showPlaceCreationFromPicker, onDismiss: {
                // Reload places and auto-select newly created place
                Task {
                    do {
                        _ = try await viewModel.vaultManager.loadPlaces()

                        // Find newly created place by sanitized name
                        if let placeName = pendingLocationName {
                            let sanitizedId = Place.sanitizeFilename(placeName)
                            if let newPlace = viewModel.vaultManager.places.first(where: { $0.id == sanitizedId }) {
                                viewModel.selectedPlace = newPlace
                            }
                        }
                    } catch {
                        print("❌ Failed to reload places: \(error)")
                    }
                }

                // Clear pending state
                pendingLocationName = nil
                pendingAddress = nil
                pendingCoordinates = nil
                pendingURL = nil
                pendingPOICategory = nil
                createPlaceRequested = false
                searchNearbyRequested = false
            }) {
                let placeViewModel = PlaceEditViewModel(
                    place: nil,
                    vaultManager: viewModel.vaultManager,
                    locationService: viewModel.locationService,
                    templateManager: TemplateManager(),
                    initialLocationName: pendingLocationName,
                    initialAddress: pendingAddress,
                    initialCoordinates: pendingCoordinates,
                    initialURL: pendingURL,
                    initialPOICategory: pendingPOICategory
                )
                PlaceEditView(viewModel: placeViewModel)
                    .environmentObject(TemplateManager())
            }
            .sheet(isPresented: $showPlaceDetails) {
                if let place = viewModel.selectedPlace {
                    PlaceDetailView(place: place)
                        .environmentObject(viewModel.vaultManager)
                        .environmentObject(viewModel.locationService)
                        .environmentObject(TemplateManager())
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
            .alert("Add Tag", isPresented: $showAddTag) {
                TextField("Tag", text: $newTag)
                Button("Add") {
                    let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !viewModel.tags.contains(trimmed) {
                        viewModel.tags.append(trimmed)
                    }
                    newTag = ""
                }
                Button("Cancel", role: .cancel) {
                    newTag = ""
                }
            } message: {
                Text("Enter a tag for this entry")
            }
        }
    }
}
