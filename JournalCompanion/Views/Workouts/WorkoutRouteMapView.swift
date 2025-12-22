//
//  WorkoutRouteMapView.swift
//  JournalCompanion
//
//  Interactive map view displaying workout route with polyline
//

import SwiftUI
import MapKit
import CoreLocation

struct WorkoutRouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    @State private var cameraPosition: MapCameraPosition

    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        _cameraPosition = State(initialValue: Self.calculateInitialPosition(coordinates))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            // Polyline overlay
            if !coordinates.isEmpty {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 3)
            }

            // Start marker
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .shadow(radius: 2)

                        Circle()
                            .fill(.green)
                            .frame(width: 16, height: 16)

                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            }

            // End marker
            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("Finish", coordinate: end) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .shadow(radius: 2)

                        Circle()
                            .fill(.red)
                            .frame(width: 16, height: 16)

                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }

    // MARK: - Helpers

    private static func calculateInitialPosition(
        _ coordinates: [CLLocationCoordinate2D]
    ) -> MapCameraPosition {
        guard !coordinates.isEmpty else {
            return .automatic
        }

        if coordinates.count == 1 {
            // Single point - center with fixed zoom
            return .region(MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        // Calculate bounding box
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add 30% padding to ensure route fits comfortably
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

#Preview {
    // Sample route coordinates (a small loop in San Francisco)
    let sampleCoordinates = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4184),
        CLLocationCoordinate2D(latitude: 37.7769, longitude: -122.4174),
        CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4164),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4174),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    ]

    WorkoutRouteMapView(coordinates: sampleCoordinates)
}
