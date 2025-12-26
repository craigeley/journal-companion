//
//  WatchConnectivityManager.swift
//  JournalCompanionWatch
//
//  Handles communication between Watch and iPhone
//

import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isCompanionAppInstalled = false
    @Published var pendingCheckInsCount = 0

    private var session: WCSession?
    private let pendingCheckInsKey = "pendingCheckIns"

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Send a check-in to the iPhone
    func sendCheckIn(_ checkIn: CheckInData) {
        guard let session = session else {
            // No session, store locally
            storePendingCheckIn(checkIn)
            return
        }

        let message: [String: Any] = [
            "type": "checkIn",
            "data": checkIn.toDictionary()
        ]

        if session.isReachable {
            // Send immediately via message
            session.sendMessage(message, replyHandler: { _ in
                // Success - check-in delivered
            }, errorHandler: { [weak self] error in
                // Failed - store for later
                Task { @MainActor in
                    self?.storePendingCheckIn(checkIn)
                }
            })
        } else {
            // Queue for background transfer
            session.transferUserInfo(message)
        }
    }

    /// Store a pending check-in locally
    private func storePendingCheckIn(_ checkIn: CheckInData) {
        var pending = loadPendingCheckIns()
        pending.append(checkIn)
        savePendingCheckIns(pending)
        pendingCheckInsCount = pending.count
    }

    /// Load pending check-ins from UserDefaults
    private func loadPendingCheckIns() -> [CheckInData] {
        guard let data = UserDefaults.standard.data(forKey: pendingCheckInsKey),
              let checkIns = try? JSONDecoder().decode([CheckInData].self, from: data) else {
            return []
        }
        return checkIns
    }

    /// Save pending check-ins to UserDefaults
    private func savePendingCheckIns(_ checkIns: [CheckInData]) {
        if let data = try? JSONEncoder().encode(checkIns) {
            UserDefaults.standard.set(data, forKey: pendingCheckInsKey)
        }
    }

    /// Attempt to sync pending check-ins
    func syncPendingCheckIns() {
        guard let session = session, session.isReachable else { return }

        let pending = loadPendingCheckIns()
        guard !pending.isEmpty else { return }

        for checkIn in pending {
            let message: [String: Any] = [
                "type": "checkIn",
                "data": checkIn.toDictionary()
            ]
            session.transferUserInfo(message)
        }

        // Clear pending after queuing
        savePendingCheckIns([])
        pendingCheckInsCount = 0
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            #if os(watchOS)
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
            #endif

            // Try to sync any pending check-ins
            if session.isReachable {
                self.syncPendingCheckIns()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable

            if session.isReachable {
                self.syncPendingCheckIns()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
