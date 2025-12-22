//
//  AudioEntryView.swift
//  JournalCompanion
//
//  Audio-only entry creation interface with metadata capture
//

import SwiftUI
import MapKit
import CoreLocation

struct AudioEntryView: View {
    @StateObject var viewModel: AudioEntryViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @State private var showPlacePicker = false

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

    // Audio recording needs vault URL
    private var vaultURL: URL? {
        viewModel.vaultManager.vaultURL
    }

    var body: some View {
        contentView
    }

    private var contentView: some View {
        NavigationStack {
            formView
                .navigationTitle("Audio Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .task {
            await viewModel.detectCurrentLocation()
        }
        .onChange(of: viewModel.showSuccess) { _, success in
            if success { dismiss() }
        }
        .sheet(isPresented: $viewModel.showAudioRecordingSheet) {
            audioRecordingSheet
        }
        .sheet(isPresented: $showPlacePicker) {
            placePickerSheet
        }
        .onChange(of: showPlacePicker) { _, isShowing in
            if !isShowing {
                // PlacePickerView dismissed
                if createPlaceRequested || searchNearbyRequested {
                    showLocationSearchForNewPlace = true
                }
            }
        }
        .sheet(isPresented: $showLocationSearchForNewPlace) {
            locationSearchSheet
        }
        .onChange(of: showLocationSearchForNewPlace) { _, isShowing in
            handleLocationSearchDismiss(isShowing)
        }
        .sheet(isPresented: $showPlaceCreationFromPicker, onDismiss: {
            handlePlaceCreationDismiss()
        }) {
            placeCreationSheet
        }
        .sheet(isPresented: $viewModel.showStateOfMindPicker) {
            stateOfMindPickerSheet
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var formView: some View {
        Form {
            audioRecordingSection
            locationSection
            weatherSection
            stateOfMindSection
            detailsSection
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button("Save") {
                Task {
                    await viewModel.createEntry()
                }
            }
            .disabled(!viewModel.isValid || viewModel.isCreating)
        }
    }

    // MARK: - Sheet Views

    private var audioRecordingSheet: some View {
        Group {
            if let vaultURL = vaultURL {
                AudioRecordingSheet(
                    vaultURL: vaultURL,
                    audioFormat: viewModel.audioFormat
                ) { url, duration, transcription, timeRanges, deviceName, sampleRate, bitDepth in
                    // Add segment to manager
                    viewModel.audioSegmentManager.addSegment(
                        tempURL: url,
                        duration: duration,
                        transcription: transcription,
                        timeRanges: timeRanges,
                        format: viewModel.audioFormat
                    )
                    // Store device metadata
                    viewModel.recordingDeviceName = deviceName
                    viewModel.recordingSampleRate = sampleRate
                    viewModel.recordingBitDepth = bitDepth
                }
            }
        }
    }

    private var placePickerSheet: some View {
        PlacePickerView(
            places: viewModel.vaultManager.places,
            currentLocation: viewModel.currentLocation,
            selectedPlace: $viewModel.selectedPlace,
            onCreatePlaceRequested: $createPlaceRequested,
            onSearchNearbyRequested: $searchNearbyRequested
        )
    }

    private var locationSearchSheet: some View {
        LocationSearchView(
            selectedLocationName: $pendingLocationName,
            selectedAddress: $pendingAddress,
            selectedCoordinates: $pendingCoordinates,
            selectedURL: $pendingURL,
            selectedPOICategory: $pendingPOICategory
        )
    }

    private var placeCreationSheet: some View {
        let placeViewModel = PlaceEditViewModel(
            place: nil,
            vaultManager: viewModel.vaultManager,
            locationService: locationService,
            templateManager: templateManager,
            initialLocationName: pendingLocationName,
            initialAddress: pendingAddress,
            initialCoordinates: pendingCoordinates,
            initialURL: pendingURL,
            initialPOICategory: pendingPOICategory
        )
        return PlaceEditView(viewModel: placeViewModel)
            .environmentObject(templateManager)
    }

    private var stateOfMindPickerSheet: some View {
        StateOfMindPickerView(
            selectedValence: $viewModel.tempMoodValence,
            selectedLabels: $viewModel.tempMoodLabels,
            selectedAssociations: $viewModel.tempMoodAssociations
        )
        .onDisappear {
            viewModel.saveStateOfMindSelection()
        }
    }

    // MARK: - Helper Methods

    private func handleLocationSearchDismiss(_ isShowing: Bool) {
        if !isShowing && pendingLocationName != nil {
            // Location selected, show place creation
            createPlaceRequested = true
            showPlaceCreationFromPicker = true
            searchNearbyRequested = false
        }
    }

    private func handlePlaceCreationDismiss() {
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
    }

    // MARK: - Section Views

    private var audioRecordingSection: some View {
        Section {
            if viewModel.audioSegmentManager.hasSegments {
                // Show recorded segments
                AudioSegmentListView(segmentManager: viewModel.audioSegmentManager)

                // Add another recording button
                Button {
                    viewModel.showAudioRecordingSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.red)
                        Text("Add Another Recording")
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            } else {
                // Show large record button
                Button {
                    viewModel.showAudioRecordingSheet = true
                } label: {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.red)
                            Text("Record Audio")
                                .font(.headline)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Audio Recording")
        } footer: {
            Text("Record voice notes with automatic transcription")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Button {
                showPlacePicker = true
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.blue)
                    if let place = viewModel.selectedPlace {
                        Text(place.name)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Select Place")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let weather = viewModel.weatherData {
            Section {
                HStack {
                    Text(weather.conditionEmoji)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(weather.temperature)°F")
                            .font(.headline)
                        Text(weather.condition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Humidity: \(weather.humidity)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let aqi = weather.aqi {
                            Text("AQI: \(aqi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

    private var stateOfMindSection: some View {
        Section {
            if let mood = viewModel.moodData {
                // Display current mood
                HStack {
                    Text(mood.emoji)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mood.description)
                            .font(.headline)
                        if !mood.associations.isEmpty {
                            Text(mood.associations.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Edit") { viewModel.openStateOfMindPicker() }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button { viewModel.clearStateOfMind() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Show add button
                Button {
                    viewModel.openStateOfMindPicker()
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                        Text("Add State of Mind")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
            }
        } header: {
            Text("State of Mind")
        } footer: {
            Text("Track your emotions and mood")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            DatePicker("Time", selection: $viewModel.timestamp)

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let viewModel = AudioEntryViewModel(vaultManager: vaultManager, locationService: locationService)
    return AudioEntryView(viewModel: viewModel)
}
