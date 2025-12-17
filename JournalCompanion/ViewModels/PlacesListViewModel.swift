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
    @Published var placesByCallout: [(callout: String, places: [Place])] = []
    @Published var searchText: String = ""
    @Published var isLoading = false

    let vaultManager: VaultManager
    let searchCoordinator: SearchCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var places: [Place] {
        vaultManager.places
    }

    init(vaultManager: VaultManager, searchCoordinator: SearchCoordinator? = nil) {
        self.vaultManager = vaultManager
        self.searchCoordinator = searchCoordinator

        // Subscribe to SearchCoordinator (if provided)
        if let searchCoordinator = searchCoordinator {
            searchCoordinator.$searchText
                .sink { [weak self] text in
                    // Only filter if Places tab (2) is active
                    if searchCoordinator.activeTab == 2 {
                        self?.filterPlaces(searchText: text)
                    }
                }
                .store(in: &cancellables)

            // Subscribe to filter changes (callout types and tags)
            Publishers.CombineLatest(
                searchCoordinator.$selectedCalloutTypes,
                searchCoordinator.$selectedTags
            )
            .sink { [weak self] callouts, tags in
                if searchCoordinator.activeTab == 2 {
                    self?.applyFilters(callouts: callouts, tags: tags)
                }
            }
            .store(in: &cancellables)
        }

        // Keep existing $searchText subscription for backward compatibility
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

        // Update grouped places whenever filteredPlaces changes
        $filteredPlaces
            .sink { [weak self] places in
                self?.updateGroupedPlaces(places)
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

    /// Apply callout type and tag filters (used by SearchCoordinator)
    private func applyFilters(callouts: Set<String>, tags: Set<String>) {
        filteredPlaces = places.filter { place in
            // Match callout type (if any callouts selected)
            let matchesCallout = callouts.isEmpty || callouts.contains(place.callout)

            // Match tags (if any tags selected, place must have at least one matching tag)
            let matchesTags = tags.isEmpty || place.tags.contains { tags.contains($0) }

            return matchesCallout && matchesTags
        }
    }

    /// Update grouped places whenever filteredPlaces changes
    private func updateGroupedPlaces(_ places: [Place]) {
        let grouped = Dictionary(grouping: places) { place in
            place.callout
        }

        placesByCallout = grouped.map { (callout: $0.key, places: $0.value) }
            .sorted { $0.callout < $1.callout }
    }
}
