//
//  SignificantLocationTracker.swift
//  JournalCompanion
//
//  Monitors significant location changes and visits in background
//

import Foundation
import Combine
import CoreLocation

class SignificantLocationTracker: NSObject, ObservableObject {
    @Published var recentVisits: [PersistedVisit] = []
    @Published var isMonitoring: Bool = false

    private let locationManager = CLLocationManager()
    private let placeMatcher = PlaceMatcher()
    private var continuation: CheckedContinuation<Void, Never>?

    private let visitsKey = "recentPersistedVisits"
    private let maxVisits = 25

    /// Places array for matching visits (updated from VaultManager)
    var places: [Place] = []

    override init() {
        super.init()
        locationManager.delegate = self
        loadPersistedVisits()
    }

    // MARK: - Persistence

    private func loadPersistedVisits() {
        guard let data = UserDefaults.standard.data(forKey: visitsKey),
              let visits = try? JSONDecoder().decode([PersistedVisit].self, from: data) else {
            return
        }
        recentVisits = visits
        print("✓ Loaded \(visits.count) persisted visits")
    }

    private func persistVisits() {
        guard let data = try? JSONEncoder().encode(recentVisits) else { return }
        UserDefaults.standard.set(data, forKey: visitsKey)
    }

    private func addVisit(_ visit: CLVisit, matchedPlace: Place?) {
        let persisted = PersistedVisit(from: visit, matchedPlaceName: matchedPlace?.name)
        recentVisits.append(persisted)

        // Trim to max visits
        if recentVisits.count > maxVisits {
            recentVisits.removeFirst(recentVisits.count - maxVisits)
        }

        persistVisits()
        print("✓ Persisted visit (total: \(recentVisits.count))")
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

            // Store visit (silently, no notification)
            addVisit(visit, matchedPlace: matchedPlace)
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
