//
//  QuickEntryViewModel.swift
//  JournalCompanion
//
//  View model for quick entry creation
//

import Foundation
import CoreLocation
import Combine
import JournalingSuggestions

@MainActor
class QuickEntryViewModel: ObservableObject {
    @Published var entryText: String = ""
    @Published var selectedPlace: Place?
    @Published var selectedPeople: [String] = []
    @Published var timestamp: Date = Date()
    @Published var tags: [String] = ["entry", "iPhone"]
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false
    @Published var currentLocation: CLLocation?
    @Published var weatherData: WeatherData?
    @Published var isFetchingWeather: Bool = false
    @Published var showSuggestionsPicker: Bool = false
    @Published var selectedSuggestion: JournalingSuggestion?

    // Track initial values to detect when weather becomes stale
    private var initialTimestamp: Date?
    private var initialLocation: CLLocation?
    private var weatherFetchedAt: Date?

    let vaultManager: VaultManager
    private let locationService: LocationService
    private let weatherService = WeatherService()
    private var cancellables = Set<AnyCancellable>()

    init(vaultManager: VaultManager, locationService: LocationService) {
        self.vaultManager = vaultManager
        self.locationService = locationService
    }

    /// Detect current location and fetch weather
    func detectCurrentLocation() async {
        currentLocation = await locationService.getCurrentLocation()

        // Fetch weather if we have a location
        if let location = currentLocation {
            await fetchWeather(for: location)
        }
    }

    /// Fetch weather data for a location
    func fetchWeather(for location: CLLocation) async {
        isFetchingWeather = true
        defer { isFetchingWeather = false }

        do {
            let weather = try await weatherService.fetchWeather(for: location, date: timestamp)
            weatherData = weather
            weatherFetchedAt = Date()

            // Track initial values for staleness detection
            if initialTimestamp == nil {
                initialTimestamp = timestamp
            }
            if initialLocation == nil {
                initialLocation = location
            }

            print("✓ Fetched weather: \(weather.temperature)°F, \(weather.condition)")
        } catch {
            print("❌ Failed to fetch weather: \(error)")
            // Don't show error to user - weather is optional
        }
    }

    /// Refresh weather data (updates initial tracking values)
    func refreshWeather() async {
        guard let location = currentLocation else { return }

        // Reset tracking to current values
        initialTimestamp = timestamp
        initialLocation = location

        // Fetch fresh weather
        await fetchWeather(for: location)
    }

    var isValid: Bool {
        !entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if weather data is stale (timestamp or location changed significantly)
    var weatherIsStale: Bool {
        guard weatherData != nil else { return false }
        guard let initialTimestamp, let initialLocation else { return false }

        // Check if timestamp changed by more than 15 minutes
        let timeDiff = abs(timestamp.timeIntervalSince(initialTimestamp))
        let timestampChanged = timeDiff > 15 * 60 // 15 minutes

        // Check if location changed by more than 100 meters
        var locationChanged = false
        if let currentLocation {
            let distance = currentLocation.distance(from: initialLocation)
            locationChanged = distance > 100 // 100 meters
        }

        return timestampChanged || locationChanged
    }

    /// Create and save entry
    func createEntry() async {
        guard isValid else { return }
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            var entry = Entry(
                id: UUID().uuidString,
                dateCreated: timestamp,
                tags: tags,
                place: selectedPlace?.name,
                people: selectedPeople,
                placeCallout: selectedPlace?.callout,
                content: entryText
            )

            // Add weather data if available
            if let weather = weatherData {
                entry.temperature = weather.temperature
                entry.condition = weather.condition
                entry.humidity = weather.humidity
                entry.aqi = weather.aqi
            }

            let writer = EntryWriter(vaultURL: vaultURL)
            try await writer.write(entry: entry)

            // Success!
            showSuccess = true
            clearForm()

            // Auto-dismiss success message
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            showSuccess = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    /// Clear the form after successful entry
    private func clearForm() {
        entryText = ""
        selectedPlace = nil
        timestamp = Date()
        tags = ["entry", "iPhone"]
        weatherData = nil
        initialTimestamp = nil
        initialLocation = nil
        weatherFetchedAt = nil
    }

    /// Add a tag if not already present
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    /// Remove a tag
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    /// Request journaling suggestions from iOS
    func requestJournalingSuggestions() {
        showSuggestionsPicker = true
    }

    /// Handle a selected journaling suggestion
    func handleSuggestion(_ suggestion: JournalingSuggestion) async {
        selectedSuggestion = suggestion

        // Extract location from suggestion if available
        let locations = await suggestion.content(forType: JournalingSuggestion.Location.self)
        if let firstLocation = locations.first,
           let location = firstLocation.location,
           let locationDate = firstLocation.date {

            // Set timestamp to when the suggestion occurred
            timestamp = locationDate

            // Try to match against existing places
            if let matchedPlace = findMatchingPlace(for: location) {
                selectedPlace = matchedPlace
            }

            // Fetch weather for suggestion location and date
            currentLocation = location
            await fetchWeather(for: location)
        }

        // Pre-populate entry text with suggestion title
        let suggestedText = suggestion.title
        if !suggestedText.isEmpty {
            entryText = suggestedText + "\n\n"
        }
    }

    /// Find a matching Place based on location proximity
    private func findMatchingPlace(for location: CLLocation) -> Place? {
        // Search for places within 100 meters
        vaultManager.places.first { place in
            guard let placeLocation = place.location else { return false }

            let placeCoordinate = CLLocation(
                latitude: placeLocation.latitude,
                longitude: placeLocation.longitude
            )

            let distance = location.distance(from: placeCoordinate)
            return distance <= 100 // Within 100 meters
        }
    }
}
