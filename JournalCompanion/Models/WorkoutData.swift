//
//  WorkoutData.swift
//  JournalCompanion
//
//  Represents a HealthKit workout for selection and sync UI
//

import Foundation
import HealthKit

struct WorkoutData: Identifiable, Sendable {
    let id: UUID  // HKWorkout UUID
    let workoutType: String  // "Running", "Cycling", "Walking", etc.
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distance: Double?  // Miles
    let calories: Int?
    let avgHeartRate: Int?
    let avgCadence: Int?  // Steps/minute for running/walking, RPM for cycling
    let hasRoute: Bool

    // Running form metrics
    let avgGroundContactTime: Double?  // milliseconds
    let avgPower: Int?  // watts
    let avgStrideLength: Double?  // meters
    let avgVerticalOscillation: Double?  // centimeters
    let avgVerticalRatio: Double?  // percent
    let totalSteps: Int?  // total step count

    // MARK: - Computed Formatting

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDistance: String? {
        guard let distance = distance else { return nil }
        return String(format: "%.2f mi", distance)
    }

    var workoutIcon: String {
        switch workoutType.lowercased() {
        case "running": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "walking": return "figure.walk"
        case "hiking": return "figure.hiking"
        case "swimming": return "figure.pool.swim"
        case "rowing": return "figure.rower"
        case "elliptical": return "figure.elliptical"
        case "yoga": return "figure.mind.and.body"
        case "strength training": return "dumbbell.fill"
        default: return "figure.run"
        }
    }
}
