//
//  GPXWriter.swift
//  JournalCompanion
//
//  Handles atomic writing of GPX route files
//

import Foundation
import CoreLocation

actor GPXWriter {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Write GPX file for entry
    /// Returns: filename (e.g., "202501151430.gpx")
    func write(
        coordinates: [CLLocationCoordinate2D],
        for entryID: String,
        workoutName: String,
        workoutType: String,
        startDate: Date
    ) async throws -> String {
        let filename = "\(entryID).gpx"
        let routesDir = vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("routes")

        // Create directory if needed
        try fileManager.createDirectory(
            at: routesDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = routesDir.appendingPathComponent(filename)

        // Generate GPX XML
        let gpxContent = generateGPX(
            coordinates: coordinates,
            name: workoutName,
            type: workoutType,
            startDate: startDate
        )

        // Write atomically
        try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)

        print("✓ Created GPX file: \(filename) with \(coordinates.count) points")
        return filename
    }

    // MARK: - Private Helpers

    private func generateGPX(
        coordinates: [CLLocationCoordinate2D],
        name: String,
        type: String,
        startDate: Date
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="JournalCompanion"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>\(escapeXML(name))</name>
    <time>\(dateFormatter.string(from: startDate))</time>
  </metadata>
  <trk>
    <name>\(escapeXML(name))</name>
    <type>\(escapeXML(type))</type>
    <trkseg>

"""

        // Add all track points
        for coord in coordinates {
            gpx += String(format: "      <trkpt lat=\"%.6f\" lon=\"%.6f\"></trkpt>\n",
                         coord.latitude,
                         coord.longitude)
        }

        gpx += """
    </trkseg>
  </trk>
</gpx>
"""

        return gpx
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
