//
//  EntryEditViewModel.swift
//  JournalCompanion
//
//  View model for editing existing journal entries
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

@MainActor
class EntryEditViewModel: ObservableObject {
    // Published properties for form binding
    @Published var entryText: String
    @Published var timestamp: Date
    @Published var selectedPlace: Place?
    @Published var tags: [String]
    @Published var temperature: Int?
    @Published var condition: String?
    @Published var aqi: Int?
    @Published var humidity: Int?
    @Published var currentLocation: CLLocation?

    @Published var isSaving = false
    @Published var saveError: String?
    @Published var showDateChangeWarning = false
    @Published var isFetchingWeather = false

    // Track initial values to detect when weather becomes stale
    private var initialTimestamp: Date?
    private var initialLocation: CLLocation?
    private var weatherFetchedAt: Date?

    // Mood data (preserved but not editable in current UI)
    private var moodValence: Double?
    private var moodLabels: [String]?
    private var moodAssociations: [String]?

    // Unknown YAML field preservation
    private var unknownFields: [String: YAMLValue]
    private var unknownFieldsOrder: [String]

    // Preserved sections (markdown headers and beyond - hidden from user editing)
    private var preservedSections: String?

    private var pendingEntry: Entry?
    private let originalEntry: Entry
    let vaultManager: VaultManager
    let locationService: LocationService
    private let weatherService = WeatherService()

    init(entry: Entry, vaultManager: VaultManager, locationService: LocationService) {
        self.originalEntry = entry
        self.vaultManager = vaultManager
        self.locationService = locationService

        // Use content directly (preserved sections are handled separately)
        self.entryText = entry.content
        self.preservedSections = entry.preservedSections

        self.timestamp = entry.dateCreated
        self.tags = entry.tags
        self.temperature = entry.temperature
        self.condition = entry.condition
        self.aqi = entry.aqi
        self.humidity = entry.humidity

        // Preserve mood data
        self.moodValence = entry.moodValence
        self.moodLabels = entry.moodLabels
        self.moodAssociations = entry.moodAssociations

        // Preserve unknown YAML fields
        self.unknownFields = entry.unknownFields
        self.unknownFieldsOrder = entry.unknownFieldsOrder

        // Look up the place if it exists
        if let placeName = entry.place {
            self.selectedPlace = vaultManager.places.first { $0.name == placeName }
        }

        // Initialize weather tracking if entry has weather data
        if entry.temperature != nil || entry.condition != nil {
            self.initialTimestamp = entry.dateCreated

            // Set initial location from place if available
            if let place = self.selectedPlace, let placeLocation = place.location {
                self.initialLocation = CLLocation(
                    latitude: placeLocation.latitude,
                    longitude: placeLocation.longitude
                )
            }
        }
    }

    /// Check if this is an audio entry (content is mirrored from SRT, read-only)
    var isAudioEntry: Bool {
        originalEntry.audioAttachments != nil && !(originalEntry.audioAttachments?.isEmpty ?? true)
    }

    /// Check if coordinates will be cleared on save (when place is added or changed)
    var coordinatesWillBeCleared: Bool {
        guard originalEntry.location != nil else { return false }

        let placeWasAdded = originalEntry.place == nil && selectedPlace?.name != nil
        let placeWasChanged = originalEntry.place != nil &&
                              selectedPlace?.name != nil &&
                              selectedPlace?.name != originalEntry.place

        return placeWasAdded || placeWasChanged
    }

    /// Save changes to the entry
    func saveChanges() async -> Bool {
        guard vaultManager.vaultURL != nil else {
            saveError = "No vault configured"
            return false
        }

        // Clean up unknown fields that conflict with known fields
        var cleanedUnknownFields = unknownFields
        var cleanedOrder = unknownFieldsOrder

        // Remove unknown fields that now have values in known fields
        if temperature != nil {
            cleanedUnknownFields.removeValue(forKey: "temp")
            cleanedOrder.removeAll { $0 == "temp" }
        }
        if condition != nil {
            cleanedUnknownFields.removeValue(forKey: "cond")
            cleanedOrder.removeAll { $0 == "cond" }
        }
        if humidity != nil {
            cleanedUnknownFields.removeValue(forKey: "humidity")
            cleanedOrder.removeAll { $0 == "humidity" }
        }
        if aqi != nil {
            cleanedUnknownFields.removeValue(forKey: "aqi")
            cleanedOrder.removeAll { $0 == "aqi" }
        }

        // Determine if coordinates should be cleared when place changes
        // Clear if place was ADDED or CHANGED (not removed)
        let shouldClearCoordinates = {
            let placeWasAdded = originalEntry.place == nil && selectedPlace?.name != nil
            let placeWasChanged = originalEntry.place != nil &&
                                  selectedPlace?.name != nil &&
                                  selectedPlace?.name != originalEntry.place

            return placeWasAdded || placeWasChanged
        }()

        let finalLocation: String? = shouldClearCoordinates ? nil : originalEntry.location

        // Create updated entry with same ID
        let updatedEntry = Entry(
            id: originalEntry.id,
            dateCreated: timestamp,
            tags: tags,
            place: selectedPlace?.name,
            people: [], // Deprecated - people now parsed from wiki-links in content
            placeCallout: selectedPlace?.callout.rawValue,
            location: finalLocation,
            content: entryText,
            preservedSections: preservedSections,
            temperature: temperature,
            condition: condition,
            aqi: aqi,
            humidity: humidity,
            moodValence: moodValence,
            moodLabels: moodLabels,
            moodAssociations: moodAssociations,
            unknownFields: cleanedUnknownFields,
            unknownFieldsOrder: cleanedOrder
        )

        // Check if the day has changed
        let calendar = Calendar.current
        let dayChanged = !calendar.isDate(originalEntry.dateCreated, inSameDayAs: updatedEntry.dateCreated)

        // If day changed, show confirmation dialog and return early
        if dayChanged {
            pendingEntry = updatedEntry
            showDateChangeWarning = true
            return false // Don't save yet, wait for confirmation
        }

        // Day hasn't changed, proceed with save
        return await performSave(updatedEntry: updatedEntry)
    }

    /// Confirm the date change and save
    func confirmDateChange() async {
        guard let entry = pendingEntry else { return }

        _ = await performSave(updatedEntry: entry)

        // Clear pending state
        pendingEntry = nil
        showDateChangeWarning = false

        // Note: The view will check saveError to determine if save succeeded
    }

    /// Perform the actual save operation
    private func performSave(updatedEntry: Entry) async -> Bool {
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            let writer = EntryWriter(vaultURL: vaultURL)

            // Check if filename changed (date/time changed enough to affect filename)
            if originalEntry.filename != updatedEntry.filename {
                // File needs to be migrated
                try await writer.updateWithDateChange(oldEntry: originalEntry, newEntry: updatedEntry)
            } else {
                // Simple in-place update
                try await writer.update(entry: updatedEntry)
            }

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Detect current location
    func detectCurrentLocation() async {
        currentLocation = await locationService.getCurrentLocation()
    }

    /// Get entry's stored coordinates as CLLocation (for entries with location but no place)
    var entryCoordinates: CLLocation? {
        guard let locationString = originalEntry.location else { return nil }

        let components = locationString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            return nil
        }

        return CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Check if entry has unsaved changes
    var hasChanges: Bool {
        // Compare content directly (preserved sections are handled separately)
        return entryText != originalEntry.content ||
        timestamp != originalEntry.dateCreated ||
        selectedPlace?.name != originalEntry.place ||
        tags != originalEntry.tags ||
        temperature != originalEntry.temperature ||
        condition != originalEntry.condition ||
        aqi != originalEntry.aqi ||
        humidity != originalEntry.humidity
    }

    /// Check if weather data is stale (timestamp or location changed significantly)
    var weatherIsStale: Bool {
        guard temperature != nil || condition != nil else { return false }
        guard let initialTimestamp else { return false }

        // Check if timestamp changed by more than 15 minutes
        let timeDiff = abs(timestamp.timeIntervalSince(initialTimestamp))
        let timestampChanged = timeDiff > 15 * 60 // 15 minutes

        // Check if selected place changed and is far from original location
        var locationChanged = false
        if let initialLocation, let selectedPlace, let placeLocation = selectedPlace.location {
            let placeCoord = CLLocation(latitude: placeLocation.latitude, longitude: placeLocation.longitude)
            let distance = placeCoord.distance(from: initialLocation)
            locationChanged = distance > 100
        }

        return timestampChanged || locationChanged
    }

    /// Refresh weather data for current timestamp and location
    func refreshWeather() async {
        // Determine location from selected place or current location
        let location: CLLocation?
        if let selectedPlace, let placeLocation = selectedPlace.location {
            location = CLLocation(latitude: placeLocation.latitude, longitude: placeLocation.longitude)
        } else {
            location = currentLocation
        }

        guard let location else { return }

        isFetchingWeather = true
        defer { isFetchingWeather = false }

        do {
            let weather = try await weatherService.fetchWeather(for: location, date: timestamp)

            // Update weather data
            temperature = weather.temperature
            condition = weather.condition
            humidity = weather.humidity
            aqi = weather.aqi
            weatherFetchedAt = Date()

            // Reset tracking to current values
            initialTimestamp = timestamp
            initialLocation = location

            print("✓ Refreshed weather: \(weather.temperature)°F, \(weather.condition)")
        } catch {
            print("❌ Failed to refresh weather: \(error)")
            // Don't show error to user - weather is optional
        }
    }
}
