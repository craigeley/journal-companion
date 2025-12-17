//
//  PlaceEditViewModel.swift
//  JournalCompanion
//
//  View model for creating and editing places
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import MapKit

@MainActor
class PlaceEditViewModel: ObservableObject {
    // Creation-specific fields
    @Published var placeName: String = ""
    @Published var selectedLocationName: String?
    @Published var selectedAddress: String?
    @Published var selectedCoordinates: CLLocationCoordinate2D?
    @Published var selectedURL: String?
    @Published var selectedPOICategory: MKPointOfInterestCategory?

    // Editable fields (both modes)
    @Published var bodyText: String = ""
    @Published var callout: String = "place"
    @Published var tags: [String] = []
    @Published var aliases: [String] = []
    @Published var url: String = ""

    // Display fields (edit mode only)
    @Published var name: String = ""
    @Published var address: String?
    @Published var location: CLLocationCoordinate2D?

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var nameError: String?

    private let originalPlace: Place?
    let vaultManager: VaultManager
    private let locationService: LocationService
    let templateManager: TemplateManager

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

    var isCreating: Bool { originalPlace == nil }

    init(
        place: Place? = nil,
        vaultManager: VaultManager,
        locationService: LocationService,
        templateManager: TemplateManager,
        initialLocationName: String? = nil,
        initialAddress: String? = nil,
        initialCoordinates: CLLocationCoordinate2D? = nil,
        initialURL: String? = nil,
        initialPOICategory: MKPointOfInterestCategory? = nil
    ) {
        self.originalPlace = place
        self.vaultManager = vaultManager
        self.locationService = locationService
        self.templateManager = templateManager

        if let place = place {
            // EDIT MODE - pre-populate all fields from existing place
            self.name = place.name
            self.bodyText = place.content
            self.address = place.address
            self.location = place.location
            self.callout = place.callout
            self.tags = place.tags
            self.aliases = place.aliases
            self.url = place.url ?? ""
        } else {
            // CREATE MODE - apply defaults and initial values
            self.selectedLocationName = initialLocationName
            self.selectedAddress = initialAddress
            self.selectedCoordinates = initialCoordinates
            self.selectedURL = initialURL
            self.selectedPOICategory = initialPOICategory

            // Auto-populate place name from location name
            if let locationName = initialLocationName {
                self.placeName = locationName
            }

            // Auto-populate URL from MapKit if available
            if let urlString = initialURL {
                self.url = urlString
            }

            // Apply template defaults
            applyTemplateDefaults()
        }
    }

    /// Apply default values from template to form fields (creation mode only)
    private func applyTemplateDefaults() {
        let template = templateManager.placeTemplate

        // Callout precedence: MapKit category > template default > "place" fallback
        if let poiCategory = selectedPOICategory,
           let mappedCallout = PlaceIcon.calloutType(from: poiCategory) {
            // Use MapKit-derived callout (highest priority)
            callout = mappedCallout
        } else if let defaultCallout = template.defaultValue(for: "callout"),
                  case .callout(let calloutType) = defaultCallout {
            // Use template default (medium priority)
            callout = calloutType
        } else {
            // Hardcoded fallback (lowest priority)
            callout = "place"
        }

        // Apply default tags (unchanged)
        if let defaultTags = template.defaultValue(for: "tags"),
           case .tags(let tagList) = defaultTags {
            tags = tagList
        } else {
            tags = ["place"]  // Fallback default
        }
    }

    /// Validation - name is required and must not conflict (pure computed property)
    var isValid: Bool {
        if isCreating {
            let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Name required
            guard !trimmedName.isEmpty else {
                return false
            }

            // Check for duplicate
            let sanitized = Place.sanitizeFilename(trimmedName)
            let exists = vaultManager.places.contains { $0.id == sanitized }

            return !exists
        } else {
            // Edit mode - always valid
            return true
        }
    }

    /// Update validation error message (call this explicitly, not during view rendering)
    func validateName() {
        guard isCreating else { return }

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

    /// Unified save method - handles both creation and editing
    func save() async -> Bool {
        guard isValid else { return false }
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            let writer = PlaceWriter(vaultURL: vaultURL, templateManager: templateManager)

            if isCreating {
                // CREATE MODE - write new place
                let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedId = Place.sanitizeFilename(trimmedName)

                let newPlace = Place(
                    id: sanitizedId,
                    name: trimmedName,
                    location: selectedCoordinates,
                    address: selectedAddress,
                    tags: tags,
                    callout: callout,
                    pin: nil,
                    color: nil,
                    url: url.isEmpty ? nil : url,
                    aliases: aliases,
                    content: bodyText
                )

                try await writer.write(place: newPlace)
            } else {
                // EDIT MODE - update existing place
                let updatedPlace = Place(
                    id: originalPlace!.id,
                    name: originalPlace!.name,  // Keep same name/ID to avoid file renaming
                    location: originalPlace!.location,  // Keep original location
                    address: originalPlace!.address,    // Keep original address
                    tags: tags,
                    callout: callout,  // NOW EDITABLE!
                    pin: originalPlace!.pin,
                    color: originalPlace!.color,
                    url: url.isEmpty ? nil : url,
                    aliases: aliases,
                    content: bodyText
                )

                try await writer.update(place: updatedPlace)
            }

            // Reload places in VaultManager to reflect changes
            _ = try await vaultManager.loadPlaces()

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Check if place has unsaved changes (edit mode only)
    var hasChanges: Bool {
        guard let original = originalPlace else { return false }

        let contentChanged = bodyText != original.content
        let aliasesChanged = aliases != original.aliases
        let tagsChanged = tags != original.tags
        let calloutChanged = callout != original.callout
        let urlChanged = (url.isEmpty ? nil : url) != original.url

        return contentChanged || aliasesChanged || tagsChanged || calloutChanged || urlChanged
    }
}
