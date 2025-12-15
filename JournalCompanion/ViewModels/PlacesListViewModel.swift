//
//  PlacesListViewModel.swift
//  JournalCompanion
//
//  View model for Places list tab
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PlacesListViewModel: ObservableObject {
    @Published var filteredPlaces: [Place] = []
    @Published var searchText: String = ""
    @Published var isLoading = false

    let vaultManager: VaultManager
    private var cancellables = Set<AnyCancellable>()

    var places: [Place] {
        vaultManager.places
    }

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        // Setup search filtering with debounce
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterPlaces(searchText: searchText)
            }
            .store(in: &cancellables)

        // Observe changes to vaultManager.places
        vaultManager.$places
            .sink { [weak self] _ in
                self?.filterPlaces(searchText: self?.searchText ?? "")
            }
            .store(in: &cancellables)
    }

    func loadPlacesIfNeeded() async {
        if places.isEmpty {
            await reloadPlaces()
        } else {
            filterPlaces(searchText: searchText)
        }
    }

    func reloadPlaces() async {
        isLoading = true
        do {
            _ = try await vaultManager.loadPlaces()
            filterPlaces(searchText: searchText)
        } catch {
            print("Failed to load places: \(error)")
        }
        isLoading = false
    }

    private func filterPlaces(searchText: String) {
        if searchText.isEmpty {
            filteredPlaces = places
        } else {
            filteredPlaces = places.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.aliases.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                place.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (place.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    /// Group places by callout type
    func placesByCallout() -> [(callout: String, places: [Place])] {
        let grouped = Dictionary(grouping: filteredPlaces) { place in
            place.callout
        }

        return grouped.map { (callout: $0.key, places: $0.value) }
            .sorted { $0.callout < $1.callout }
    }
}
