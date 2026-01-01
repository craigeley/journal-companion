//
//  SignificantLocationTracker.swift
//  JournalCompanion
//
//  Monitors significant location changes and visits in background
//

import Foundation
import Combine
import CoreLocation
import UserNotifications

class SignificantLocationTracker: NSObject, ObservableObject {
    @Published var recentVisits: [CLVisit] = []
    @Published var isMonitoring: Bool = false

    private let locationManager = CLLocationManager()
    private let placeMatcher = PlaceMatcher()
    private var continuation: CheckedContinuation<Void, Never>?

    /// Places array for matching visits (updated from VaultManager)
    var places: [Place] = []

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Request "Always" authorization for background tracking
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Start monitoring visits (requires "Always" permission)
    func startMonitoring() {
        guard locationManager.authorizationStatus == .authorizedAlways else {
            print("⚠️ Visit monitoring requires 'Always' location permission")
            return
        }

        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
        print("✓ Started monitoring visits and significant locations")
    }

    /// Stop monitoring
    func stopMonitoring() {
        locationManager.stopMonitoringVisits()
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
        print("✓ Stopped monitoring visits")
    }

    /// Request notification permission
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }

    /// Send notification for visit departure
    private func sendVisitNotification(for visit: CLVisit, matchedPlace: Place?) {
        let content = UNMutableNotificationContent()

        if let place = matchedPlace {
            content.title = "Visit to \(place.name)"
            content.body = "Would you like to log this visit?"
        } else {
            content.title = "Location Visit"
            content.body = "Would you like to log your recent visit?"
        }

        content.sound = .default
        content.categoryIdentifier = "VISIT_CATEGORY"

        // Store visit data for later use
        content.userInfo = [
            "visitLatitude": visit.coordinate.latitude,
            "visitLongitude": visit.coordinate.longitude,
            "visitArrivalDate": visit.arrivalDate.timeIntervalSince1970,
            "visitDepartureDate": visit.departureDate.timeIntervalSince1970,
            "placeName": matchedPlace?.name ?? ""
        ]

        // Send immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✓ Sent visit notification")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SignificantLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            // Only notify on departure (when we know the full visit duration)
            guard visit.departureDate != Date.distantFuture else {
                print("📍 Visit started at \(visit.coordinate.latitude), \(visit.coordinate.longitude)")
                return
            }

            print("📍 Visit ended at \(visit.coordinate.latitude), \(visit.coordinate.longitude)")
            print("   Duration: \(visit.arrivalDate) to \(visit.departureDate)")

            // Store visit
            recentVisits.append(visit)
            if recentVisits.count > 10 {
                recentVisits.removeFirst()
            }

            // Try to match to a known place
            let visitLocation = CLLocation(
                latitude: visit.coordinate.latitude,
                longitude: visit.coordinate.longitude
            )

            let matchedPlace = placeMatcher.findClosestPlace(to: visitLocation, in: places)?.place

            if let place = matchedPlace {
                print("✓ Matched visit to place: \(place.name)")
            } else {
                print("ℹ️ No matching place found for visit")
            }

            sendVisitNotification(for: visit, matchedPlace: matchedPlace)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                print("📍 Significant location change: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            print("📍 Location authorization changed: \(status.rawValue)")

            if status == .authorizedAlways && !isMonitoring {
                startMonitoring()
            } else if status != .authorizedAlways && isMonitoring {
                stopMonitoring()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error)")
    }
}
