//
//  HealthKitService.swift
//  JournalCompanion
//
//  Manages HealthKit State of Mind operations
//

import Foundation
import HealthKit

actor HealthKitService {
    private let healthStore = HKHealthStore()

    // MARK: - Authorization

    /// Request authorization for State of Mind data
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let stateOfMindType = HKObjectType.stateOfMindType()

        print("📋 Requesting HealthKit authorization for State of Mind...")

        // Request authorization - system will show dialog
        try await healthStore.requestAuthorization(
            toShare: [stateOfMindType],
            read: [stateOfMindType]
        )

        print("✅ HealthKit authorization request completed")
    }

    /// Check current authorization status
    func authorizationStatus() -> HKAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available (checking status)")
            return .notDetermined
        }

        let stateOfMindType = HKObjectType.stateOfMindType()
        let status = healthStore.authorizationStatus(for: stateOfMindType)
        print("📊 Current HealthKit authorization status: \(status.rawValue) (\(statusDescription(status)))")
        return status
    }

    private func statusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not determined"
        case .sharingDenied: return "denied"
        case .sharingAuthorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Save

    /// Save State of Mind sample to HealthKit
    func saveMood(
        valence: Double,
        labels: [HKStateOfMind.Label],
        associations: [HKStateOfMind.Association],
        date: Date
    ) async throws {
        let stateOfMind = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: valence,
            labels: labels,
            associations: associations
        )

        try await healthStore.save(stateOfMind)
        print("✓ Saved State of Mind to HealthKit: valence=\(valence)")
    }

    // MARK: - Query (for future trends features)

    /// Query State of Mind samples for a date range
    func queryMoods(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKStateOfMind] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.stateOfMind(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        return try await descriptor.result(for: healthStore)
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied. Please enable in Settings."
        case .saveFailed:
            return "Failed to save State of Mind to HealthKit"
        }
    }
}
