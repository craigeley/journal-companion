//
//  QuickEntryView.swift
//  JournalCompanion
//
//  Quick entry creation interface
//

import SwiftUI
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif
import MapKit
import CoreLocation

struct QuickEntryView: View {
    @StateObject var viewModel: QuickEntryViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
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
        NavigationStack {
            Form {
                // Entry Section
                Section("Entry") {
                    SmartTextEditor(
                        text: $viewModel.entryText,
                        places: viewModel.vaultManager.places,
                        people: viewModel.vaultManager.people,
                        minHeight: 120
                    )
                    .focused($isTextFieldFocused)
                }

                // Location Section
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

                #if canImport(JournalingSuggestions)
                // Suggestions Section
                Section {
                    Button {
                        viewModel.requestJournalingSuggestions()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("Get Suggestions")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                } footer: {
                    Text("See AI-powered suggestions from your day: photos, workouts, places, and more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif

                // Weather Section
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

                // State of Mind Section
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

                // Audio Recording Section
                Section {
                    if viewModel.audioSegmentManager.hasSegments {
                        // Show recorded segments
                        AudioSegmentListView(segmentManager: viewModel.audioSegmentManager)
                    } else {
                        // Show add button
                        Button {
                            viewModel.showAudioRecordingSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "mic.circle")
                                    .foregroundStyle(.red)
                                Text("Add Audio Recording")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("Audio Recording")
                } footer: {
                    Text("Record voice notes with automatic transcription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Details Section
                Section("Details") {
                    DatePicker("Time", selection: $viewModel.timestamp)

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    viewModel.removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createEntry()
                            if viewModel.showSuccess {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextFieldFocused = true
                viewModel.showSuccess = false
                Task {
                    await viewModel.detectCurrentLocation()
                }
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
            .sheet(isPresented: $showPlacePicker) {
                PlacePickerView(
                    places: viewModel.vaultManager.places,
                    currentLocation: viewModel.currentLocation,
                    entryCoordinates: nil,
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
                        // Location was selected, create and show PlaceEditView
                        placeCreationViewModel = PlaceEditViewModel(
                            place: nil,
                            vaultManager: viewModel.vaultManager,
                            locationService: LocationService(),
                            templateManager: TemplateManager(),
                            initialLocationName: pendingLocationName,
                            initialAddress: pendingAddress,
                            initialCoordinates: pendingCoordinates,
                            initialURL: pendingURL,
                            initialPOICategory: pendingPOICategory
                        )
                    } else {
                        // User cancelled, reset flags
                        createPlaceRequested = false
                        searchNearbyRequested = false
                    }
                }
            }
            .sheet(item: $placeCreationViewModel) { viewModel in
                PlaceEditView(viewModel: viewModel)
                    .environmentObject(TemplateManager())
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
                StateOfMindPickerView(
                    selectedValence: $viewModel.tempMoodValence,
                    selectedLabels: $viewModel.tempMoodLabels,
                    selectedAssociations: $viewModel.tempMoodAssociations
                )
                .onDisappear {
                    if viewModel.showStateOfMindPicker == false {
                        viewModel.saveStateOfMindSelection()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAudioRecordingSheet) {
                if let vaultURL = viewModel.vaultManager.vaultURL {
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
                        // Store metadata from first recording
                        viewModel.recordingDeviceName = deviceName
                        viewModel.recordingSampleRate = sampleRate
                        viewModel.recordingBitDepth = bitDepth
                    }
                } else {
                    Text("Vault not configured")
                        .foregroundStyle(.secondary)
                }
            }
            #if canImport(JournalingSuggestions)
            .journalingSuggestionsPicker(
                isPresented: $viewModel.showSuggestionsPicker,
                onCompletion: { suggestion in
                    // User selected a suggestion
                    Task {
                        await viewModel.handleSuggestion(suggestion)
                    }
                }
            )
            #endif
        }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    let tag: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Person Chip
struct PersonChip: View {
    let name: String
    let onTap: (() -> Void)?
    let onDelete: () -> Void

    init(name: String, onTap: (() -> Void)? = nil, onDelete: @escaping () -> Void) {
        self.name = name
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 4) {
            // Tappable area for person name/icon
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                Text(name)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            // Separate delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let viewModel = QuickEntryViewModel(vaultManager: vaultManager, locationService: locationService)
    return QuickEntryView(viewModel: viewModel)
}
