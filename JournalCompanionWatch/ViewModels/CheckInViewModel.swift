//
//  CheckInViewModel.swift
//  JournalCompanionWatch
//
//  Coordinates the check-in flow on Apple Watch
//

import Foundation
import CoreLocation
import WatchKit

@MainActor
class CheckInViewModel: ObservableObject {
    // MARK: - Published State

    @Published var locationStatus: WatchLocationService.LocationStatus = .unknown
    @Published var showNoteInput = false
    @Published var isProcessing = false
    @Published var showConfirmation = false
    @Published var todayCount = 0
    @Published var errorMessage: String?

    // MARK: - Services

    private let locationService = WatchLocationService()
    private let connectivity = WatchConnectivityManager.shared

    // MARK: - Captured Data

    private var capturedLocation: CLLocation?
    private var capturedTime: Date?

    // MARK: - Constants

    private let todayCountKey = "todayCheckInCount"
    private let lastCheckInDateKey = "lastCheckInDate"

    // MARK: - Init

    init() {
        loadTodayCount()
        observeLocationStatus()
    }

    private func observeLocationStatus() {
        // Observe location service status changes
        Task {
            for await status in locationService.$locationStatus.values {
                self.locationStatus = status
            }
        }
    }

    // MARK: - Check-In Flow

    /// Start a new check-in - captures time and requests location
    func startCheckIn() {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil
        capturedTime = Date()

        Task {
            // Capture location (with timeout)
            capturedLocation = await locationService.getCurrentLocation(timeout: 10.0)

            // Show note input sheet
            showNoteInput = true
            isProcessing = false
        }
    }

    /// Complete the check-in with an optional note
    func completeCheckIn(note: String?) {
        guard let timestamp = capturedTime else {
            errorMessage = "No check-in in progress"
            return
        }

        let checkIn = CheckInData(
            timestamp: timestamp,
            location: capturedLocation?.coordinate,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // Send to iPhone
        connectivity.sendCheckIn(checkIn)

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Update count
        incrementTodayCount()

        // Reset state
        showNoteInput = false
        capturedLocation = nil
        capturedTime = nil

        // Show confirmation briefly
        showConfirmation = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showConfirmation = false
        }
    }

    /// Skip adding a note and complete check-in
    func skipNote() {
        completeCheckIn(note: nil)
    }

    /// Cancel the current check-in
    func cancelCheckIn() {
        showNoteInput = false
        capturedLocation = nil
        capturedTime = nil
        isProcessing = false
    }

    // MARK: - Today Count Management

    private func loadTodayCount() {
        let defaults = UserDefaults.standard

        // Check if we need to reset count (new day)
        if let lastDate = defaults.object(forKey: lastCheckInDateKey) as? Date {
            if !Calendar.current.isDateInToday(lastDate) {
                // New day - reset count
                defaults.set(0, forKey: todayCountKey)
                defaults.set(Date(), forKey: lastCheckInDateKey)
            }
        }

        todayCount = defaults.integer(forKey: todayCountKey)
    }

    private func incrementTodayCount() {
        todayCount += 1
        let defaults = UserDefaults.standard
        defaults.set(todayCount, forKey: todayCountKey)
        defaults.set(Date(), forKey: lastCheckInDateKey)
    }

    // MARK: - Computed Properties

    var locationStatusText: String {
        switch locationStatus {
        case .unknown:
            return "Ready"
        case .requesting:
            return "Getting location..."
        case .authorized:
            return "Location enabled"
        case .denied:
            return "Location disabled"
        case .acquired:
            return "Location captured"
        case .failed:
            return "Location unavailable"
        }
    }

    var locationStatusIcon: String {
        switch locationStatus {
        case .unknown, .authorized:
            return "location.circle"
        case .requesting:
            return "location.circle.fill"
        case .denied:
            return "location.slash"
        case .acquired:
            return "location.fill"
        case .failed:
            return "location.slash.circle"
        }
    }

    var hasLocation: Bool {
        capturedLocation != nil
    }

    var isConnectedToPhone: Bool {
        connectivity.isReachable
    }

    var pendingCount: Int {
        connectivity.pendingCheckInsCount
    }
}
