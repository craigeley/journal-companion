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

    private let originalEntry: Entry
    let vaultManager: VaultManager
    private let locationService: LocationService

    init(entry: Entry, vaultManager: VaultManager, locationService: LocationService) {
        self.originalEntry = entry
        self.vaultManager = vaultManager
        self.locationService = locationService

        // Pre-populate with existing entry data
        self.entryText = entry.content
        self.timestamp = entry.dateCreated
        self.tags = entry.tags
        self.temperature = entry.temperature
        self.condition = entry.condition
        self.aqi = entry.aqi
        self.humidity = entry.humidity

        // Look up the place if it exists
        if let placeName = entry.place {
            self.selectedPlace = vaultManager.places.first { $0.name == placeName }
        }
    }

    /// Save changes to the entry
    func saveChanges() async -> Bool {
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            // Create updated entry with same ID
            let updatedEntry = Entry(
                id: originalEntry.id,
                dateCreated: timestamp,
                tags: tags,
                place: selectedPlace?.name,
                placeCallout: selectedPlace?.callout,
                content: entryText,
                temperature: temperature,
                condition: condition,
                aqi: aqi,
                humidity: humidity
            )

            // Update the entry file
            let writer = EntryWriter(vaultURL: vaultURL)
            try await writer.update(entry: updatedEntry)

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

    /// Check if entry has unsaved changes
    var hasChanges: Bool {
        entryText != originalEntry.content ||
        timestamp != originalEntry.dateCreated ||
        selectedPlace?.name != originalEntry.place ||
        tags != originalEntry.tags ||
        temperature != originalEntry.temperature ||
        condition != originalEntry.condition ||
        aqi != originalEntry.aqi ||
        humidity != originalEntry.humidity
    }
}
