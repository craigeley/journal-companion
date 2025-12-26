//
//  WatchLocationService.swift
//  JournalCompanionWatch
//
//  Watch-optimized location service for check-ins
//

import Foundation
import CoreLocation

@MainActor
class WatchLocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var locationStatus: LocationStatus = .unknown

    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    enum LocationStatus: Equatable {
        case unknown
        case requesting
        case authorized
        case denied
        case acquired
        case failed
    }

    override init() {
        super.init()
        locationManager.delegate = self
        // Use reduced accuracy for faster results on watch
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationStatus()
    }

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Get current location with timeout
    /// Returns nil if location cannot be acquired within timeout
    func getCurrentLocation(timeout: TimeInterval = 10.0) async -> CLLocation? {
        // Check authorization status
        if authorizationStatus == .notDetermined {
            locationStatus = .requesting
            requestPermission()
            // Wait for authorization response
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        guard isAuthorized else {
            locationStatus = .denied
            return nil
        }

        locationStatus = .requesting

        // Request location
        locationManager.requestLocation()

        // Wait for location update with timeout
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            // Set up timeout
            self.timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                // If still waiting, return last known location or nil
                if self.continuation != nil {
                    await MainActor.run {
                        self.locationStatus = .failed
                        let lastLocation = self.locationManager.location
                        self.continuation?.resume(returning: lastLocation)
                        self.continuation = nil
                    }
                }
            }
        }
    }

    private func updateAuthorizationStatus() {
        isAuthorized = (authorizationStatus == .authorizedWhenInUse ||
                       authorizationStatus == .authorizedAlways)

        if isAuthorized {
            locationStatus = .authorized
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            locationStatus = .denied
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension WatchLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.updateAuthorizationStatus()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // Cancel timeout
            self.timeoutTask?.cancel()
            self.timeoutTask = nil

            // Only process if we have a continuation waiting
            if let continuation = self.continuation {
                self.currentLocation = location
                self.locationStatus = .acquired
                continuation.resume(returning: location)
                self.continuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Cancel timeout
            self.timeoutTask?.cancel()
            self.timeoutTask = nil

            self.locationStatus = .failed

            // Resume continuation with last known location or nil
            if let continuation = self.continuation {
                let lastLocation = manager.location
                continuation.resume(returning: lastLocation)
                self.continuation = nil
            }
        }
    }
}
