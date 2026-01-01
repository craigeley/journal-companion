//
//  VisitNotificationCoordinator.swift
//  JournalCompanion
//
//  Coordinates visit notification handling and entry pre-population
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Data extracted from a visit notification
struct VisitNotificationData: Equatable {
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date
    let placeName: String?

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
}

@MainActor
class VisitNotificationCoordinator: ObservableObject {
    /// The pending visit data from a notification tap
    @Published var pendingVisitData: VisitNotificationData?

    /// Trigger to show quick entry with visit data
    @Published var shouldShowQuickEntry: Bool = false

    /// Handle a visit notification tap
    func handleVisitNotification(_ data: VisitNotificationData) {
        pendingVisitData = data
        shouldShowQuickEntry = true
        print("✓ Visit notification handled: \(data.placeName ?? "Unknown location")")
        print("  Coordinates: \(data.latitude), \(data.longitude)")
        print("  Duration: \(data.durationString)")
    }

    /// Clear the pending visit data
    func clearPendingVisit() {
        pendingVisitData = nil
        shouldShowQuickEntry = false
    }
}
