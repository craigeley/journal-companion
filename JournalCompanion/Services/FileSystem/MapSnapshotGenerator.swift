//
//  MapSnapshotGenerator.swift
//  JournalCompanion
//
//  Generates static PNG maps for workout routes
//

import Foundation
import MapKit
import UIKit
import CoreLocation

actor MapSnapshotGenerator {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Generate static map image for entry
    /// Returns: filename (e.g., "202501151430-map.png")
    func generateMap(
        coordinates: [CLLocationCoordinate2D],
        for entryID: String
    ) async throws -> String {
        let filename = "\(entryID)-map.png"
        let mapsDir = vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("maps")

        try fileManager.createDirectory(
            at: mapsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = mapsDir.appendingPathComponent(filename)

        // Use MapKit MKMapSnapshotter
        let image = try await createSnapshot(coordinates: coordinates)

        // Write PNG
        if let pngData = image.pngData() {
            try pngData.write(to: fileURL, options: .atomic)
            print("✓ Created map image: \(filename)")
            return filename
        } else {
            throw MapError.imageGenerationFailed
        }
    }

    // MARK: - Private Helpers

    private func createSnapshot(
        coordinates: [CLLocationCoordinate2D]
    ) async throws -> UIImage {
        // Calculate bounding box and region
        let region = calculateRegion(for: coordinates)

        // Configure snapshotter
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 800, height: 600)
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        // Take snapshot
        let snapshot = try await snapshotter.start()

        // Draw polyline on snapshot (must run on main thread)
        return await drawRoute(
            on: snapshot.image,
            coordinates: coordinates,
            in: snapshot
        )
    }

    private func calculateRegion(
        for coordinates: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default to San Francisco if no coordinates
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        if coordinates.count == 1 {
            // Single point
            return MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
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

        // Add 30% padding
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    @MainActor
    private func drawRoute(
        on baseImage: UIImage,
        coordinates: [CLLocationCoordinate2D],
        in snapshot: MKMapSnapshotter.Snapshot
    ) -> UIImage {
        // Use UIGraphicsImageRenderer to overlay polyline
        let renderer = UIGraphicsImageRenderer(size: baseImage.size)

        return renderer.image { context in
            // Draw base map
            baseImage.draw(at: .zero)

            // Convert coordinates to points on the snapshot
            var points: [CGPoint] = []
            for coordinate in coordinates {
                let point = snapshot.point(for: coordinate)
                points.append(point)
            }

            // Draw polyline
            guard points.count >= 2 else { return }

            let path = UIBezierPath()
            path.move(to: points[0])

            for i in 1..<points.count {
                path.addLine(to: points[i])
            }

            // Style the path
            UIColor.systemBlue.setStroke()
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            // Draw start marker (green)
            if let start = points.first {
                drawMarker(at: start, color: .systemGreen)
            }

            // Draw end marker (red)
            if points.count > 1, let end = points.last {
                drawMarker(at: end, color: .systemRed)
            }
        }
    }

    private func drawMarker(at point: CGPoint, color: UIColor) {
        let markerSize: CGFloat = 16
        let markerRect = CGRect(
            x: point.x - markerSize / 2,
            y: point.y - markerSize / 2,
            width: markerSize,
            height: markerSize
        )

        let markerPath = UIBezierPath(ovalIn: markerRect)
        color.setFill()
        markerPath.fill()

        // White border
        UIColor.white.setStroke()
        markerPath.lineWidth = 2
        markerPath.stroke()
    }
}

// MARK: - Errors

enum MapError: LocalizedError {
    case imageGenerationFailed

    var errorDescription: String? {
        switch self {
        case .imageGenerationFailed:
            return "Failed to generate map image"
        }
    }
}
