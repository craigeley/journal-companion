//
//  QuickEntryViewModel.swift
//  JournalCompanion
//
//  View model for quick entry creation
//

import Foundation
import CoreLocation
import Combine

@MainActor
class QuickEntryViewModel: ObservableObject {
    @Published var entryText: String = ""
    @Published var selectedPlace: Place?
    @Published var timestamp: Date = Date()
    @Published var tags: [String] = ["entry", "iPhone"]
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false
    @Published var currentLocation: CLLocation?

    let vaultManager: VaultManager
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    init(vaultManager: VaultManager, locationService: LocationService) {
        self.vaultManager = vaultManager
        self.locationService = locationService
    }

    /// Detect current location
    func detectCurrentLocation() async {
        currentLocation = await locationService.getCurrentLocation()
    }

    var isValid: Bool {
        !entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            let entry = Entry(
                id: UUID().uuidString,
                dateCreated: timestamp,
                tags: tags,
                place: selectedPlace?.name,
                placeCallout: selectedPlace?.callout,
                content: entryText
            )

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
}
