//
//  PlaceEditViewModel.swift
//  JournalCompanion
//
//  View model for editing places
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
class PlaceEditViewModel: ObservableObject {
    // Editable content
    @Published var bodyText: String

    // Read-only metadata (displayed but not editable in v1)
    @Published var name: String
    @Published var address: String?
    @Published var location: CLLocationCoordinate2D?
    @Published var tags: [String]
    @Published var callout: String
    @Published var url: String?
    @Published var aliases: [String]

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?

    private let originalPlace: Place
    let vaultManager: VaultManager
    let templateManager: TemplateManager

    init(place: Place, vaultManager: VaultManager, templateManager: TemplateManager) {
        self.originalPlace = place
        self.vaultManager = vaultManager
        self.templateManager = templateManager

        // Pre-populate with existing data
        self.bodyText = place.content
        self.name = place.name
        self.address = place.address
        self.location = place.location
        self.tags = place.tags
        self.callout = place.callout
        self.url = place.url
        self.aliases = place.aliases
    }

    /// Save changes to the place
    func saveChanges() async -> Bool {
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            // Create updated place with same ID (filename)
            // In v1, content, tags, and aliases are editable; other fields stay the same
            let updatedPlace = Place(
                id: originalPlace.id,
                name: originalPlace.name,  // Not editable yet
                location: originalPlace.location,
                address: originalPlace.address,
                tags: tags,  // Use edited tags
                callout: originalPlace.callout,
                pin: originalPlace.pin,
                color: originalPlace.color,
                url: originalPlace.url,
                aliases: aliases,  // Use edited aliases
                content: bodyText  // Only this changes
            )

            // Update the place file
            let writer = PlaceWriter(vaultURL: vaultURL, templateManager: templateManager)
            try await writer.update(place: updatedPlace)

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

    /// Check if place has unsaved changes
    var hasChanges: Bool {
        let contentChanged = bodyText != originalPlace.content
        let aliasesChanged = aliases != originalPlace.aliases
        let tagsChanged = tags != originalPlace.tags
        return contentChanged || aliasesChanged || tagsChanged
    }
}
