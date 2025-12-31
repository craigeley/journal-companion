//
//  PhotoEntryView.swift
//  JournalCompanion
//
//  Photo entry creation interface with EXIF metadata extraction
//

import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct PhotoEntryView: View {
    @StateObject var viewModel: PhotoEntryViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @State private var showPlacePicker = false

    // Place creation flow state
    @State private var showLocationSearchForNewPlace = false
    @State private var placeCreationViewModel: PlaceEditViewModel?
    @State private var pendingLocationName: String?
    @State private var pendingAddress: String?
    @State private var pendingCoordinates: CLLocationCoordinate2D?
    @State private var pendingURL: String?
    @State private var pendingPOICategory: MKPointOfInterestCategory?
    @State private var createPlaceRequested = false
    @State private var searchNearbyRequested = false

    var body: some View {
        contentView
    }

    private var contentView: some View {
        NavigationStack {
            formView
                .navigationTitle("Photo Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .task {
            // Auto-load photo if pre-selected
            if viewModel.selectedPhotoItem != nil && viewModel.photoImage == nil {
                await viewModel.handlePhotoSelection(viewModel.selectedPhotoItem)
            }
        }
        .onChange(of: viewModel.showSuccess) { _, success in
            if success { dismiss() }
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
        .sheet(item: $placeCreationViewModel) { viewModel in
            PlaceEditView(viewModel: viewModel)
                .environmentObject(templateManager)
        }
        .onChange(of: placeCreationViewModel?.createdPlace) { oldValue, newValue in
            if let newPlace = newValue {
                // Auto-select the newly created place
                viewModel.selectedPlace = newPlace

                // Clear pending state
                pendingLocationName = nil
                pendingAddress = nil
                pendingCoordinates = nil
                pendingURL = nil
                pendingPOICategory = nil
                createPlaceRequested = false
                searchNearbyRequested = false

                // Dismiss sheet
                placeCreationViewModel = nil
            }
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
            photoSection
            if viewModel.photoImage != nil {
                entryContentSection
            }
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

    private var placePickerSheet: some View {
        PlacePickerView(
            places: viewModel.vaultManager.places,
            currentLocation: viewModel.currentLocation,
            entryCoordinates: nil,
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
            // Location selected, create and show PlaceEditView
            placeCreationViewModel = PlaceEditViewModel(
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
        }
    }

    // MARK: - Section Views

    private var entryContentSection: some View {
        Section {
            SmartTextEditor(
                text: $viewModel.entryContent,
                places: viewModel.vaultManager.places,
                people: viewModel.vaultManager.people,
                minHeight: 120
            )
            .font(.body)
        } header: {
            Text("Entry")
        } footer: {
            Text("Add notes or context about this photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var photoSection: some View {
        Section {
            if viewModel.isLoadingPhoto {
                // Loading state
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading photo...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else if let image = viewModel.photoImage {
                // Photo selected - show preview
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        Label("Change Photo", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
                        Task {
                            await viewModel.handlePhotoSelection(newItem)
                        }
                    }

                    // Camera metadata display
                    if let exif = viewModel.photoEXIF, exif.hasCameraInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            if let camera = exif.cameraModel {
                                HStack {
                                    Image(systemName: "camera")
                                        .foregroundStyle(.secondary)
                                    Text(camera)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let lens = exif.lensModel {
                                HStack {
                                    Image(systemName: "camera.aperture")
                                        .foregroundStyle(.secondary)
                                    Text(lens)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            if let summary = exif.cameraInfoSummary, exif.cameraModel == nil {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                }
            } else {
                // No photo selected - show picker (fallback if opened without photo)
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("Select Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
                .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
                    Task {
                        await viewModel.handlePhotoSelection(newItem)
                    }
                }
            }
        } header: {
            Text("Photo")
        } footer: {
            if viewModel.photoImage == nil {
                Text("Select a photo from your library. Location and time will be extracted from photo metadata if available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let exif = viewModel.photoEXIF {
                VStack(alignment: .leading, spacing: 2) {
                    if exif.hasLocation {
                        Label("Location extracted from photo", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if exif.hasTimestamp {
                        Label("Timestamp extracted from photo", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if !exif.hasLocation && !exif.hasTimestamp {
                        Text("No EXIF metadata found in photo")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        Section {
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

            // Show location source hint
            if viewModel.locationSource == .exif && viewModel.selectedPlace != nil {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Auto-matched from photo GPS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Location")
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
    let viewModel = PhotoEntryViewModel(vaultManager: vaultManager, locationService: locationService)
    return PhotoEntryView(viewModel: viewModel)
}
