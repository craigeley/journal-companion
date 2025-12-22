//
//  WorkoutSyncViewModel.swift
//  JournalCompanion
//
//  Manages workout selection and syncing from HealthKit
//

import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreLocation

@MainActor
class WorkoutSyncViewModel: ObservableObject {
    @Published var workouts: [WorkoutData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncedWorkoutIDs: Set<UUID> = []

    let vaultManager: VaultManager
    private lazy var healthKitService = HealthKitService()
    private var existingWorkoutIDs: Set<String> = []

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Loading

    func loadWorkouts() async {
        isLoading = true
        defer { isLoading = false }

        // Load existing entries to detect duplicates
        await loadExistingWorkoutIDs()

        do {
            // Request authorization first
            try await healthKitService.requestWorkoutAuthorization()

            // Query workouts
            let workoutData = try await healthKitService.queryWorkouts()
            workouts = workoutData
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadExistingWorkoutIDs() async {
        guard let vaultURL = vaultManager.vaultURL else { return }

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            // Load recent entries (no limit - load all for duplicate detection)
            let entries = try await reader.loadEntries()

            // Extract healthkit_workout_id from unknownFields
            existingWorkoutIDs = Set(
                entries.compactMap { $0.healthKitWorkoutID }
            )

            print("✓ Found \(existingWorkoutIDs.count) existing workout entries")
        } catch {
            print("⚠️ Failed to load existing entries: \(error)")
        }
    }

    // MARK: - Duplicate Detection

    func isAlreadySynced(_ workoutID: UUID) -> Bool {
        existingWorkoutIDs.contains(workoutID.uuidString) ||
        syncedWorkoutIDs.contains(workoutID)
    }

    var filteredWorkouts: [WorkoutData] {
        // Future: Add filters by workout type, date range, etc.
        workouts
    }

    // MARK: - Syncing

    func syncWorkout(_ workout: WorkoutData) async {
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        do {
            // Extract route if available
            var coordinates: [CLLocationCoordinate2D]? = nil
            if workout.hasRoute {
                print("📍 Extracting route for \(workout.workoutType)...")
                coordinates = try await healthKitService.extractRoute(for: workout.id)
                print("✓ Extracted \(coordinates?.count ?? 0) coordinates")
            }

            // Create entry ID from workout start date
            let entryID = formatEntryID(workout.startDate)

            // Build tags
            let tags = ["workout", workout.workoutType.lowercased(), "HealthKit", "iPhone"]

            // Create entry content
            let content = generateWorkoutContent(workout)

            // Create entry with weather data from HealthKit
            var entry = Entry(
                id: entryID,
                dateCreated: workout.startDate,
                tags: tags,
                place: nil,
                people: [],
                placeCallout: nil,
                content: content,
                temperature: workout.temperature,
                condition: workout.condition,
                aqi: nil,
                humidity: workout.humidity,
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

            // Add workout metadata to unknownFields
            entry.unknownFields["healthkit_workout_id"] = .string(workout.id.uuidString)
            entry.unknownFieldsOrder.append("healthkit_workout_id")

            entry.unknownFields["workout_type"] = .string(workout.workoutType)
            entry.unknownFieldsOrder.append("workout_type")

            // Add starting location if route available
            if let coords = coordinates, let first = coords.first {
                let locationString = String(format: "%.5f,%.5f", first.latitude, first.longitude)
                entry.unknownFields["location"] = .string(locationString)
                entry.unknownFieldsOrder.append("location")
            }

            if let distance = workout.distance {
                entry.unknownFields["distance"] = .double(distance)
                entry.unknownFieldsOrder.append("distance")
            }

            let duration = formatDuration(workout.duration)
            entry.unknownFields["time"] = .string(duration)
            entry.unknownFieldsOrder.append("time")

            // Calculate pace if we have distance and duration
            if let distance = workout.distance, distance > 0 {
                let paceMinutesPerMile = workout.duration / 60.0 / distance
                let paceMinutes = Int(paceMinutesPerMile)
                let paceSeconds = Int((paceMinutesPerMile - Double(paceMinutes)) * 60)
                let pace = String(format: "%d:%02d", paceMinutes, paceSeconds)
                entry.unknownFields["pace"] = .string(pace)
                entry.unknownFieldsOrder.append("pace")
            }

            if let calories = workout.calories {
                entry.unknownFields["calories"] = .int(calories)
                entry.unknownFieldsOrder.append("calories")
            }

            if let hr = workout.avgHeartRate {
                entry.unknownFields["avg_hr"] = .int(hr)
                entry.unknownFieldsOrder.append("avg_hr")
            }

            if let cadence = workout.avgCadence {
                entry.unknownFields["avg_cadence"] = .int(cadence)
                entry.unknownFieldsOrder.append("avg_cadence")
            }

            // MARK: Advanced running form metrics (disabled to reduce YAML clutter)
            // These metrics are still extracted from HealthKit and available in WorkoutData
            // Can be re-enabled or made optional via settings in the future

            // if let power = workout.avgPower {
            //     entry.unknownFields["avg_power"] = .int(power)
            //     entry.unknownFieldsOrder.append("avg_power")
            // }
            //
            // if let groundContactTime = workout.avgGroundContactTime {
            //     entry.unknownFields["avg_stance_time"] = .double(groundContactTime)
            //     entry.unknownFieldsOrder.append("avg_stance_time")
            // }
            //
            // if let strideLength = workout.avgStrideLength {
            //     entry.unknownFields["avg_step_length"] = .double(strideLength * 1000) // convert to mm
            //     entry.unknownFieldsOrder.append("avg_step_length")
            // }
            //
            // if let verticalOscillation = workout.avgVerticalOscillation {
            //     entry.unknownFields["avg_vertical_oscillation"] = .double(verticalOscillation * 10) // convert to mm
            //     entry.unknownFieldsOrder.append("avg_vertical_oscillation")
            // }
            //
            // if let verticalRatio = workout.avgVerticalRatio {
            //     entry.unknownFields["avg_vertical_ratio"] = .double(verticalRatio)
            //     entry.unknownFieldsOrder.append("avg_vertical_ratio")
            // }
            //
            // if let steps = workout.totalSteps {
            //     entry.unknownFields["total_strides"] = .int(steps)
            //     entry.unknownFieldsOrder.append("total_strides")
            // }

            // Write entry
            let writer = EntryWriter(vaultURL: vaultURL)

            if let coords = coordinates, !coords.isEmpty {
                // Write workout entry with route
                try await writer.writeWorkoutEntry(
                    entry: entry,
                    coordinates: coords,
                    workoutName: workout.workoutType,
                    workoutType: workout.workoutType
                )
            } else {
                // Write regular entry (no route)
                try await writer.write(entry: entry)
            }

            // Mark as synced
            syncedWorkoutIDs.insert(workout.id)
            existingWorkoutIDs.insert(workout.id.uuidString)

            print("✅ Synced \(workout.workoutType) workout")

            // Trigger VaultManager refresh by loading entries
            Task {
                _ = try? await vaultManager.loadEntries()
            }

        } catch {
            errorMessage = "Failed to sync workout: \(error.localizedDescription)"
            print("❌ Sync failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func formatEntryID(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func generateWorkoutContent(_ workout: WorkoutData) -> String {
        var content = "\(workout.workoutType) workout"

        var details: [String] = []

        if let distance = workout.formattedDistance {
            details.append(distance)
        }

        details.append(workout.formattedDuration)

        if let calories = workout.calories {
            details.append("\(calories) kcal")
        }

        if !details.isEmpty {
            content += " - " + details.joined(separator: ", ")
        }

        content += "."

        return content
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
