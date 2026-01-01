//
//  DailyNoteSettingsView.swift
//  JournalCompanion
//
//  Settings for daily note weather metadata
//

import SwiftUI
import MapKit

struct DailyNoteSettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @AppStorage("dailyNoteWeatherLatitude") private var weatherLatitude: Double = 0.0
    @AppStorage("dailyNoteWeatherLongitude") private var weatherLongitude: Double = 0.0
    @AppStorage("dailyNoteWeatherLocationName") private var weatherLocationName: String = ""

    @State private var showLocationPicker = false
    @State private var isUpdating = false
    @State private var updateMessage: String?

    var hasLocationSet: Bool {
        weatherLatitude != 0.0 && weatherLongitude != 0.0
    }

    var body: some View {
        Form {
            Section {
                if hasLocationSet {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !weatherLocationName.isEmpty {
                            Text(weatherLocationName)
                                .font(.body)
                        }

                        Text("Lat: \(weatherLatitude, specifier: "%.4f"), Lon: \(weatherLongitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Button("Change Location") {
                        showLocationPicker = true
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No weather location set")
                            .foregroundStyle(.secondary)

                        Text("Select a location to fetch weather forecasts for daily notes.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Button("Set Location") {
                        showLocationPicker = true
                    }
                }
            } header: {
                Text("Weather Location")
            } footer: {
                Text("Weather forecasts for daily notes will use this location. Update this setting when you travel to a new area.")
            }

            Section {
                Button {
                    updateAllDayFiles()
                } label: {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isUpdating ? "Updating..." : "Update All Daily Notes")
                    }
                }
                .disabled(!hasLocationSet || isUpdating)

                if let message = updateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Update Existing Files")
            } footer: {
                Text("Scans all daily note files and adds weather metadata (high/low temps, sunrise/sunset) to those with empty frontmatter.")
            }
        }
        .navigationTitle("Daily Notes")
        .sheet(isPresented: $showLocationPicker) {
            WeatherLocationPicker(
                selectedLocationName: $weatherLocationName,
                selectedLatitude: $weatherLatitude,
                selectedLongitude: $weatherLongitude
            )
        }
    }

    private func updateAllDayFiles() {
        guard hasLocationSet, let vaultURL = vaultManager.vaultURL else { return }

        isUpdating = true
        updateMessage = nil

        Task {
            do {
                let location = CLLocation(latitude: weatherLatitude, longitude: weatherLongitude)
                let manager = DailyNoteManager(vaultURL: vaultURL)
                let count = try await manager.updateAllDayFilesWithWeatherMetadata(location: location)

                await MainActor.run {
                    isUpdating = false
                    updateMessage = "✓ Updated \(count) daily notes"
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    updateMessage = "⚠️ Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Weather Location Picker
struct WeatherLocationPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocationName: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a location", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Search results
                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectLocation(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .foregroundStyle(.primary)
                                if let address = item.address {
                                    Text(formatAddress(address))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Map
                Map(position: $cameraPosition) {
                    if let coordinate = selectedCoordinate {
                        Marker("Weather Location", coordinate: coordinate)
                            .tint(.blue)
                    }
                }
                .mapControlVisibility(.visible)
            }
            .navigationTitle("Select Weather Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let coordinate = selectedCoordinate {
                            selectedLatitude = coordinate.latitude
                            selectedLongitude = coordinate.longitude
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Search error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            searchResults = response.mapItems
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        selectedCoordinate = coordinate

        let addressStr = item.address.map { formatAddress($0) } ?? ""
        selectedLocationName = item.name ?? addressStr

        // Update map camera
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )

        // Clear search
        searchText = ""
        searchResults = []
    }

    private func formatAddress(_ address: MKAddress) -> String {
        // Use shortAddress for compact display (iOS 26+)
        return address.shortAddress ?? address.fullAddress
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DailyNoteSettingsView()
            .environmentObject(VaultManager())
    }
}
