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

    let vaultManager: VaultManager
    private var cancellables = Set<AnyCancellable>()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        // Filter places with valid coordinates
        vaultManager.$places
            .map { places in
                places.filter { place in
                    guard let location = place.location else { return false }
                    return CLLocationCoordinate2DIsValid(location)
                }
            }
            .assign(to: &$placesWithCoordinates)

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
        let coordinates = placesWithCoordinates.compactMap { $0.location }

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
}
