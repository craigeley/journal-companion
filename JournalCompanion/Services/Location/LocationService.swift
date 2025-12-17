//
//  LocationService.swift
//  JournalCompanion
//
//  Handles location permissions and current location access
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var hasAlwaysAuthorization: Bool = false

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationStatus()
    }

    /// Request "When In Use" location permission (for quick entries)
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request "Always" location permission (for background visit tracking)
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Get current location (requests permission if needed)
    func getCurrentLocation() async -> CLLocation? {
        // Check authorization status
        if authorizationStatus == .notDetermined {
            requestPermission()
            // Wait a moment for the alert to appear
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        guard isAuthorized else {
            print("Location access not authorized")
            return nil
        }

        // Request location
        locationManager.requestLocation()

        // Wait for location update
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func updateAuthorizationStatus() {
        isAuthorized = (authorizationStatus == .authorizedWhenInUse ||
                       authorizationStatus == .authorizedAlways)
        hasAlwaysAuthorization = (authorizationStatus == .authorizedAlways)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.updateAuthorizationStatus()
            print("Location authorization changed: \(self.authorizationStatus.rawValue)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // Only process if we have a continuation waiting (first update only)
            if let continuation = self.continuation {
                self.currentLocation = location
                print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                continuation.resume(returning: location)
                self.continuation = nil
            }
            // Ignore subsequent updates - we already returned from getCurrentLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error)")

            // Resume continuation with nil if waiting
            if let continuation = self.continuation {
                continuation.resume(returning: nil)
                self.continuation = nil
            }
        }
    }
}
