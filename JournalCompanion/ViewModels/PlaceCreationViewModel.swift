//
//  PlaceCreationViewModel.swift
//  JournalCompanion
//
//  View model for place creation
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
class PlaceCreationViewModel: ObservableObject {
    // Form fields
    @Published var placeName: String = ""
    @Published var selectedLocationName: String?
    @Published var selectedAddress: String?
    @Published var selectedCoordinates: CLLocationCoordinate2D?
    @Published var selectedCallout: String = "place"
    @Published var notes: String = ""

    // UI state
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var nameError: String?
    @Published var creationSucceeded: Bool = false

    let vaultManager: VaultManager
    private let locationService: LocationService

    // Available callout types (matches PlaceIcon supported types)
    static let calloutTypes = [
        "place",      // Default
        "cafe",
        "restaurant",
        "park",
        "school",
        "home",
        "shop",
        "grocery",
        "bar",
        "medical",
        "airport",
        "hotel",
        "library",
        "zoo",
        "museum",
        "workout",
        "concert",
        "movie",
        "entertainment",
        "service"
    ]

    init(
        vaultManager: VaultManager,
        locationService: LocationService,
        initialLocationName: String? = nil,
        initialAddress: String? = nil,
        initialCoordinates: CLLocationCoordinate2D? = nil
    ) {
        self.vaultManager = vaultManager
        self.locationService = locationService

        // Pre-populate location data if provided
        self.selectedLocationName = initialLocationName
        self.selectedAddress = initialAddress
        self.selectedCoordinates = initialCoordinates

        // Auto-populate place name from location name
        if let locationName = initialLocationName {
            self.placeName = locationName
        }
    }

    /// Validation - name is required and must not conflict (pure computed property)
    var isValid: Bool {
        let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Name required
        guard !trimmedName.isEmpty else {
            return false
        }

        // Check for duplicate
        let sanitized = Place.sanitizeFilename(trimmedName)
        let exists = vaultManager.places.contains { $0.id == sanitized }

        return !exists
    }

    /// Update validation error message (call this explicitly, not during view rendering)
    func validateName() {
        let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            nameError = "Name is required"
            return
        }

        let sanitized = Place.sanitizeFilename(trimmedName)
        let exists = vaultManager.places.contains { $0.id == sanitized }

        if exists {
            nameError = "A place with this name already exists"
        } else {
            nameError = nil
        }
    }

    /// Create and save place
    func createPlace() async {
        guard isValid else { return }
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedId = Place.sanitizeFilename(trimmedName)

            // Create new place
            let newPlace = Place(
                id: sanitizedId,
                name: trimmedName,
                location: selectedCoordinates,
                address: selectedAddress,
                tags: ["place"],  // Default tag
                callout: selectedCallout,
                pin: nil,         // Let PlaceIcon defaults handle this
                color: nil,       // Let PlaceIcon defaults handle this
                url: nil,
                aliases: [],      // Start with no aliases
                content: notes
            )

            // Write place file
            let writer = PlaceWriter(vaultURL: vaultURL)
            try await writer.write(place: newPlace)

            // Reload places in VaultManager
            _ = try await vaultManager.loadPlaces()

            // Success
            creationSucceeded = true
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    /// Clear form after successful creation
    private func clearForm() {
        placeName = ""
        selectedLocationName = nil
        selectedAddress = nil
        selectedCoordinates = nil
        selectedCallout = "place"
        notes = ""
    }
}
