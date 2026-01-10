//
//  PersistedVisit.swift
//  JournalCompanion
//
//  Codable representation of CLVisit for UserDefaults persistence
//

import Foundation
import CoreLocation

struct PersistedVisit: Codable, Identifiable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date
    let horizontalAccuracy: Double
    let matchedPlaceName: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var duration: TimeInterval {
        departureDate.timeIntervalSince(arrivalDate)
    }

    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    init(from visit: CLVisit, matchedPlaceName: String?) {
        self.id = UUID()
        self.latitude = visit.coordinate.latitude
        self.longitude = visit.coordinate.longitude
        self.arrivalDate = visit.arrivalDate
        self.departureDate = visit.departureDate
        self.horizontalAccuracy = visit.horizontalAccuracy
        self.matchedPlaceName = matchedPlaceName
    }
}
