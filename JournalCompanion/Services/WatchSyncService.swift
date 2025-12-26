//
//  WatchSyncService.swift
//  JournalCompanion
//
//  Receives check-ins from Apple Watch and writes them to vault
//

import Foundation
import WatchConnectivity
import CoreLocation

@MainActor
class WatchSyncService: NSObject, ObservableObject {
    static let shared = WatchSyncService()

    @Published var isWatchPaired = false
    @Published var isWatchReachable = false
    @Published var lastSyncDate: Date?

    private var session: WCSession?
    private weak var vaultManager: VaultManager?

    override init() {
        super.init()
    }

    /// Configure the service with vault manager
    func configure(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Process a check-in received from watch
    private func processCheckIn(_ data: [String: Any]) async {
        guard let vaultManager = vaultManager,
              let vaultURL = vaultManager.vaultURL else {
            print("WatchSyncService: No vault configured")
            return
        }

        // Parse check-in data
        guard let id = data["id"] as? String,
              let timestampInterval = data["timestamp"] as? TimeInterval else {
            print("WatchSyncService: Invalid check-in data")
            return
        }

        let timestamp = Date(timeIntervalSince1970: timestampInterval)
        let hasLocation = data["hasLocation"] as? Bool ?? false
        let note = data["note"] as? String ?? ""

        // Build location string
        var locationString: String?
        if hasLocation,
           let lat = data["latitude"] as? Double,
           let lon = data["longitude"] as? Double {
            locationString = "\(lat),\(lon)"
        }

        // Create entry
        var entry = Entry.create(
            content: note,
            location: locationString,
            tags: ["checkin", "watch"]
        )

        // Override the auto-generated date with the check-in timestamp
        entry = Entry(
            id: id,
            dateCreated: timestamp,
            tags: entry.tags,
            place: nil,
            people: [],
            placeCallout: nil,
            location: locationString,
            content: note,
            temperature: nil,
            condition: nil,
            aqi: nil,
            humidity: nil,
            moodValence: nil,
            moodLabels: nil,
            moodAssociations: nil,
            audioAttachments: nil,
            recordingDevice: nil,
            sampleRate: nil,
            bitDepth: nil,
            unknownFields: [:],
            unknownFieldsOrder: []
        )

        // Try to match location to a known place
        if hasLocation,
           let lat = data["latitude"] as? Double,
           let lon = data["longitude"] as? Double {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            if let matchedPlace = findNearbyPlace(coordinate: coordinate, places: vaultManager.places) {
                entry = Entry(
                    id: entry.id,
                    dateCreated: entry.dateCreated,
                    tags: entry.tags,
                    place: matchedPlace.name,
                    people: [],
                    placeCallout: matchedPlace.callout,
                    location: locationString,
                    content: note,
                    temperature: nil,
                    condition: nil,
                    aqi: nil,
                    humidity: nil,
                    moodValence: nil,
                    moodLabels: nil,
                    moodAssociations: nil,
                    audioAttachments: nil,
                    recordingDevice: nil,
                    sampleRate: nil,
                    bitDepth: nil,
                    unknownFields: [:],
                    unknownFieldsOrder: []
                )
            }
        }

        // Write entry to vault
        let writer = EntryWriter(vaultURL: vaultURL)
        do {
            try await writer.write(entry)
            print("WatchSyncService: Check-in saved successfully")

            // Refresh entries list
            await vaultManager.loadEntries()

            lastSyncDate = Date()
        } catch {
            print("WatchSyncService: Failed to write entry: \(error)")
        }
    }

    /// Find a place within 100 meters of the given coordinate
    private func findNearbyPlace(coordinate: CLLocationCoordinate2D, places: [Place]) -> Place? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let maxDistance: CLLocationDistance = 100 // meters

        for place in places {
            guard let placeCoord = place.location else { continue }
            let placeLocation = CLLocation(latitude: placeCoord.latitude, longitude: placeCoord.longitude)
            let distance = location.distance(from: placeLocation)

            if distance <= maxDistance {
                return place
            }
        }

        return nil
    }
}

// MARK: - WCSessionDelegate
extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
        }
    }

    // Handle messages sent immediately
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String, type == "checkIn",
              let data = message["data"] as? [String: Any] else {
            return
        }

        Task { @MainActor in
            await self.processCheckIn(data)
        }
    }

    // Handle messages with reply handler
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String, type == "checkIn",
              let data = message["data"] as? [String: Any] else {
            replyHandler(["success": false])
            return
        }

        Task { @MainActor in
            await self.processCheckIn(data)
            replyHandler(["success": true])
        }
    }

    // Handle background transfers (queued when watch was unreachable)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let type = userInfo["type"] as? String, type == "checkIn",
              let data = userInfo["data"] as? [String: Any] else {
            return
        }

        Task { @MainActor in
            await self.processCheckIn(data)
        }
    }
}
