//
//  CheckInData.swift
//  JournalCompanionWatch
//
//  Data model for watch check-ins sent to iPhone
//

import Foundation
import CoreLocation

/// Represents a check-in captured on Apple Watch
struct CheckInData: Codable, Sendable {
    let id: String
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
    let note: String?

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        location: CLLocationCoordinate2D? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = location?.latitude
        self.longitude = location?.longitude
        self.note = note
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Convert to dictionary for WatchConnectivity transfer
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "timestamp": timestamp.timeIntervalSince1970,
            "hasLocation": hasLocation
        ]

        if let lat = latitude {
            dict["latitude"] = lat
        }
        if let lon = longitude {
            dict["longitude"] = lon
        }
        if let note = note, !note.isEmpty {
            dict["note"] = note
        }

        return dict
    }

    /// Create from dictionary received via WatchConnectivity
    static func fromDictionary(_ dict: [String: Any]) -> CheckInData? {
        guard let id = dict["id"] as? String,
              let timestampInterval = dict["timestamp"] as? TimeInterval else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: timestampInterval)
        let hasLocation = dict["hasLocation"] as? Bool ?? false

        var coordinate: CLLocationCoordinate2D?
        if hasLocation,
           let lat = dict["latitude"] as? Double,
           let lon = dict["longitude"] as? Double {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let note = dict["note"] as? String

        return CheckInData(
            id: id,
            timestamp: timestamp,
            location: coordinate,
            note: note
        )
    }
}
