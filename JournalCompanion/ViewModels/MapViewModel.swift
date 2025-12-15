//
//  MapViewModel.swift
//  JournalCompanion
//
//  View model for Map tab
//

import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var placesWithCoordinates: [Place] = []
    @Published var isLoading = false

    // Filter state
    @Published var filteredPlaces: [Place] = []
    @Published var selectedCalloutTypes: Set<String> = []
    @Published var selectedTags: Set<String> = []
    @Published var availableTags: [String] = []

    let vaultManager: VaultManager
    private var cancellables = Set<AnyCancellable>()

    // All available callout types
    let allCalloutTypes: [String] = [
        "place", "cafe", "restaurant", "park", "school", "home",
        "shop", "grocery", "bar", "medical", "airport", "hotel",
        "library", "zoo", "museum", "workout", "concert", "movie",
        "entertainment", "service"
    ]

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        // Initialize filters to "all selected" (show everything)
        self.selectedCalloutTypes = Set(allCalloutTypes)

        // Filter places with valid coordinates
        vaultManager.$places
            .map { places in
                places.filter { place in
                    guard let location = place.location else { return false }
                    return CLLocationCoordinate2DIsValid(location)
                }
            }
            .sink { [weak self] places in
                self?.placesWithCoordinates = places
                self?.updateAvailableTags()
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // React to filter changes
        Publishers.CombineLatest($selectedCalloutTypes, $selectedTags)
            .sink { [weak self] _, _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        vaultManager.$isLoadingPlaces
            .assign(to: &$isLoading)
    }

    func loadPlacesIfNeeded() async {
        if vaultManager.places.isEmpty {
            do {
                _ = try await vaultManager.loadPlaces()
            } catch {
                print("Failed to load places: \(error)")
            }
        }
    }

    func calculateInitialRegion() -> MapCameraPosition {
        let coordinates = filteredPlaces.compactMap { $0.location }

        guard !coordinates.isEmpty else {
            // Default fallback region
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }

        if coordinates.count == 1 {
            // Single place: center with reasonable zoom
            return .region(MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }

        // Multiple places: calculate bounding box
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add 20% padding to span
        let latDelta = max((maxLat - minLat) * 1.2, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.2, 0.01)

        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        ))
    }

    // MARK: - Filtering

    /// Extract unique tags from current places with coordinates
    private func updateAvailableTags() {
        let allTags = placesWithCoordinates.flatMap { $0.tags }
        let uniqueTags = Set(allTags)
            .filter { !$0.isEmpty && $0 != "place" }
            .sorted()

        availableTags = uniqueTags

        // Initialize tag selection to all available tags
        if selectedTags.isEmpty && !uniqueTags.isEmpty {
            selectedTags = Set(uniqueTags)
        }
    }

    /// Apply callout and tag filters to places
    private func applyFilters() {
        filteredPlaces = placesWithCoordinates.filter { place in
            // Filter by callout type
            let matchesCallout = selectedCalloutTypes.contains(place.callout)

            // Filter by tags (ANY matching - place needs at least one selected tag)
            let matchesTags: Bool = {
                // If no tags are selected or available, show all places
                if selectedTags.isEmpty || availableTags.isEmpty {
                    return true
                }
                // Place must have at least one tag that's selected
                return place.tags.contains { selectedTags.contains($0) }
            }()

            return matchesCallout && matchesTags
        }
    }

    /// Toggle a callout type selection
    func toggleCalloutType(_ callout: String) {
        if selectedCalloutTypes.contains(callout) {
            selectedCalloutTypes.remove(callout)
        } else {
            selectedCalloutTypes.insert(callout)
        }
    }

    /// Toggle a tag selection
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Reset all filters to default (all selected)
    func resetFilters() {
        selectedCalloutTypes = Set(allCalloutTypes)
        selectedTags = Set(availableTags)
    }

    /// Check if any filters are active (not all selected)
    var hasActiveFilters: Bool {
        selectedCalloutTypes.count < allCalloutTypes.count ||
        (!availableTags.isEmpty && selectedTags.count < availableTags.count)
    }
}
