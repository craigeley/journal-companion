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
    @Published var placesByCallout: [(callout: PlaceCallout, places: [Place])] = []
    @Published var searchText: String = ""
    @Published var selectedCalloutTypes: Set<PlaceCallout> = []
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
                    // Filter if Places tab (2) or Search tab (4) is active
                    if searchCoordinator.activeTab == 2 || searchCoordinator.activeTab == 4 {
                        self?.searchText = text
                    }
                }
                .store(in: &cancellables)

            // Subscribe to filter changes (callout types and tags)
            Publishers.CombineLatest(
                searchCoordinator.$selectedCalloutTypes,
                searchCoordinator.$selectedTags
            )
            .sink { [weak self] callouts, tags in
                // Apply filters if Places tab (2) or Search tab (4) is active
                if searchCoordinator.activeTab == 2 || searchCoordinator.activeTab == 4 {
                    self?.applyFilters(callouts: callouts, tags: tags)
                }
            }
            .store(in: &cancellables)
        }

        // Observe changes to vaultManager.places
        vaultManager.$places
            .sink { [weak self] _ in
                self?.filterPlaces()
            }
            .store(in: &cancellables)

        // React to filter changes (debounced) - combines search and callout type filters
        Publishers.CombineLatest($searchText, $selectedCalloutTypes)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.filterPlaces()
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
            filterPlaces()
        }
    }

    func reloadPlaces() async {
        isLoading = true
        do {
            _ = try await vaultManager.loadPlaces()
            filterPlaces()
        } catch {
            print("Failed to load places: \(error)")
        }
        isLoading = false
    }

    private func filterPlaces() {
        var result = places

        // Filter by selected callout types (empty = show all)
        if !selectedCalloutTypes.isEmpty {
            result = result.filter { selectedCalloutTypes.contains($0.callout) }
        }

        // Filter by search text (from SearchCoordinator or local)
        if !searchText.isEmpty {
            result = result.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.aliases.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                place.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (place.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        filteredPlaces = result
    }

    /// Toggle a callout type filter
    func toggleCalloutType(_ callout: PlaceCallout) {
        if selectedCalloutTypes.contains(callout) {
            selectedCalloutTypes.remove(callout)
        } else {
            selectedCalloutTypes.insert(callout)
        }
    }

    /// Check if a callout type is selected
    func isCalloutTypeSelected(_ callout: PlaceCallout) -> Bool {
        selectedCalloutTypes.contains(callout)
    }

    /// Clear filters (show all)
    func clearCalloutTypeFilters() {
        selectedCalloutTypes = []
    }

    /// Apply callout type and tag filters (used by SearchCoordinator)
    private func applyFilters(callouts: Set<String>, tags: Set<String>) {
        filteredPlaces = places.filter { place in
            // Match callout type (if any callouts selected)
            let matchesCallout = callouts.isEmpty || callouts.contains(place.callout.rawValue)

            // Match tags (if any tags selected, place must have at least one matching tag)
            let matchesTags = tags.isEmpty || place.tags.contains { tags.contains($0) }

            return matchesCallout && matchesTags
        }
    }

    /// Update grouped places whenever filteredPlaces changes
    private func updateGroupedPlaces(_ places: [Place]) {
        let grouped = Dictionary(grouping: places) { $0.callout }

        // Sort by callout display order, only include types that have places
        placesByCallout = PlaceCallout.allCases
            .compactMap { callout in
                guard let items = grouped[callout], !items.isEmpty else { return nil }
                return (callout: callout, places: items.sorted { $0.name < $1.name })
            }
    }
}
