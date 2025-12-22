//
//  HealthKitService.swift
//  JournalCompanion
//
//  Manages HealthKit State of Mind and Workout operations
//

import Foundation
import HealthKit
import CoreLocation

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

    // MARK: - Workouts

    /// Request authorization for workout and route data
    func requestWorkoutAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .cyclingCadence)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .runningGroundContactTime)!,
            HKObjectType.quantityType(forIdentifier: .runningPower)!,
            HKObjectType.quantityType(forIdentifier: .runningStrideLength)!,
            HKObjectType.quantityType(forIdentifier: .runningVerticalOscillation)!
        ]

        print("📋 Requesting HealthKit authorization for workouts...")

        try await healthStore.requestAuthorization(
            toShare: [],
            read: typesToRead
        )

        print("✅ HealthKit workout authorization request completed")
    }

    /// Query recent workouts (last 90 days by default)
    func queryWorkouts(
        from startDate: Date = Calendar.current.date(byAdding: .day, value: -90, to: Date())!,
        to endDate: Date = Date()
    ) async throws -> [WorkoutData] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let workouts = try await descriptor.result(for: healthStore)

        print("✓ Found \(workouts.count) workouts in HealthKit")

        // Convert to WorkoutData with route detection
        return await withTaskGroup(of: WorkoutData?.self) { group in
            for workout in workouts {
                group.addTask {
                    await self.convertToWorkoutData(workout)
                }
            }

            var results: [WorkoutData] = []
            for await data in group {
                if let data = data {
                    results.append(data)
                }
            }
            // Sort by start date (newest first) since TaskGroup doesn't preserve order
            return results.sorted { $0.startDate > $1.startDate }
        }
    }

    /// Extract route coordinates from a workout
    func extractRoute(for workoutID: UUID) async throws -> [CLLocationCoordinate2D] {
        // Find the workout first
        let workoutPredicate = HKQuery.predicateForObjects(with: [workoutID])
        let workoutDescriptor = HKSampleQueryDescriptor(
            predicates: [.workout(workoutPredicate)],
            sortDescriptors: []
        )

        let workouts = try await workoutDescriptor.result(for: healthStore)
        guard let workout = workouts.first else {
            throw HealthKitError.workoutNotFound
        }

        var coordinates: [CLLocationCoordinate2D] = []

        return try await withCheckedThrowingContinuation { continuation in
            let routeQuery = HKAnchoredObjectQuery(
                type: HKSeriesType.workoutRoute(),
                predicate: HKQuery.predicateForObjects(from: workout),
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { query, samples, deletedObjects, anchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let routes = samples as? [HKWorkoutRoute], let route = routes.first else {
                    continuation.resume(returning: [])
                    return
                }

                // Extract location data from route
                let locationQuery = HKWorkoutRouteQuery(route: route) { query, locations, done, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let locations = locations {
                        coordinates.append(contentsOf: locations.map { $0.coordinate })
                    }

                    if done {
                        print("✓ Extracted \(coordinates.count) coordinates from route")
                        continuation.resume(returning: coordinates)
                    }
                }

                self.healthStore.execute(locationQuery)
            }

            healthStore.execute(routeQuery)
        }
    }

    // MARK: - Private Helpers

    private func convertToWorkoutData(_ workout: HKWorkout) async -> WorkoutData? {
        let workoutType = workoutTypeName(workout.workoutActivityType)

        // Check if workout has a route
        let hasRoute = await checkForRoute(workout)

        // Extract distance (convert to miles)
        let distance: Double? = {
            if let quantity = workout.totalDistance {
                let miles = quantity.doubleValue(for: HKUnit.mile())
                return miles
            }
            return nil
        }()

        // Extract calories
        let calories: Int? = {
            if #available(iOS 18.0, *) {
                if let stats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
                   let quantity = stats.sumQuantity() {
                    let kcal = quantity.doubleValue(for: HKUnit.kilocalorie())
                    return Int(kcal)
                }
            } else {
                if let quantity = workout.totalEnergyBurned {
                    let kcal = quantity.doubleValue(for: HKUnit.kilocalorie())
                    return Int(kcal)
                }
            }
            return nil
        }()

        // Extract average heart rate
        let avgHeartRate: Int? = {
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let stats = workout.statistics(for: heartRateType),
               let avgQuantity = stats.averageQuantity() {
                let bpm = avgQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                return Int(bpm)
            }
            return nil
        }()

        // Extract average cadence
        // For cycling: direct from cyclingCadence
        // For running: calculate from step count
        var avgCadence: Int? = nil
        var totalSteps: Int? = nil

        if workout.workoutActivityType == .cycling {
            if let cadenceType = HKQuantityType.quantityType(forIdentifier: .cyclingCadence),
               let stats = workout.statistics(for: cadenceType),
               let avgQuantity = stats.averageQuantity() {
                let rpm = avgQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                avgCadence = Int(rpm)
            }
        } else if workout.workoutActivityType == .running ||
                  workout.workoutActivityType == .walking ||
                  workout.workoutActivityType == .hiking {
            // Get step count to calculate cadence
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
               let stats = workout.statistics(for: stepType),
               let sumQuantity = stats.sumQuantity() {
                let steps = sumQuantity.doubleValue(for: .count())
                totalSteps = Int(steps)
                // Calculate cadence: steps per minute
                // HealthKit stepCount already counts both feet during workouts
                if workout.duration > 0 {
                    let minutes = workout.duration / 60.0
                    avgCadence = Int(steps / minutes)
                }
            }
        }

        // Extract running form metrics
        let avgGroundContactTime: Double? = {
            if let type = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime),
               let stats = workout.statistics(for: type),
               let avgQuantity = stats.averageQuantity() {
                return avgQuantity.doubleValue(for: .secondUnit(with: .milli))
            }
            return nil
        }()

        let avgPower: Int? = {
            if let type = HKQuantityType.quantityType(forIdentifier: .runningPower),
               let stats = workout.statistics(for: type),
               let avgQuantity = stats.averageQuantity() {
                return Int(avgQuantity.doubleValue(for: .watt()))
            }
            return nil
        }()

        let avgStrideLength: Double? = {
            if let type = HKQuantityType.quantityType(forIdentifier: .runningStrideLength),
               let stats = workout.statistics(for: type),
               let avgQuantity = stats.averageQuantity() {
                return avgQuantity.doubleValue(for: .meter())
            }
            return nil
        }()

        let avgVerticalOscillation: Double? = {
            if let type = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation),
               let stats = workout.statistics(for: type),
               let avgQuantity = stats.averageQuantity() {
                return avgQuantity.doubleValue(for: .meterUnit(with: .centi))
            }
            return nil
        }()

        // Calculate vertical ratio if we have both metrics
        let avgVerticalRatio: Double? = {
            if let vo = avgVerticalOscillation, let sl = avgStrideLength, sl > 0 {
                // Convert stride length from meters to centimeters
                let slCm = sl * 100
                return (vo / slCm) * 100 // percentage
            }
            return nil
        }()

        // Extract weather data from workout metadata
        let temperature: Int? = {
            if let metadata = workout.metadata,
               let tempQuantity = metadata[HKMetadataKeyWeatherTemperature] as? HKQuantity {
                let fahrenheit = tempQuantity.doubleValue(for: HKUnit.degreeFahrenheit())
                return Int(fahrenheit.rounded())
            }
            return nil
        }()

        let condition: String? = {
            if let metadata = workout.metadata,
               let conditionNumber = metadata[HKMetadataKeyWeatherCondition] as? NSNumber,
               let weatherCondition = HKWeatherCondition(rawValue: conditionNumber.intValue) {
                // Convert HKWeatherCondition to lowercase string matching Entry format
                return weatherConditionString(weatherCondition)
            }
            return nil
        }()

        let humidity: Int? = {
            if let metadata = workout.metadata,
               let humidityQuantity = metadata[HKMetadataKeyWeatherHumidity] as? HKQuantity {
                let percent = humidityQuantity.doubleValue(for: HKUnit.percent())
                return Int(percent.rounded())
            }
            return nil
        }()

        return WorkoutData(
            id: workout.uuid,
            workoutType: workoutType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distance: distance,
            calories: calories,
            avgHeartRate: avgHeartRate,
            avgCadence: avgCadence,
            hasRoute: hasRoute,
            avgGroundContactTime: avgGroundContactTime,
            avgPower: avgPower,
            avgStrideLength: avgStrideLength,
            avgVerticalOscillation: avgVerticalOscillation,
            avgVerticalRatio: avgVerticalRatio,
            totalSteps: totalSteps,
            temperature: temperature,
            condition: condition,
            humidity: humidity
        )
    }

    private func checkForRoute(_ workout: HKWorkout) async -> Bool {
        let routePredicate = HKQuery.predicateForObjects(from: workout)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: routePredicate,
                limit: 1,
                sortDescriptors: nil
            ) { query, samples, error in
                continuation.resume(returning: (samples?.count ?? 0) > 0)
            }

            healthStore.execute(query)
        }
    }

    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        // Exercise and fitness
        case .running: return "Running"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .wheelchairWalkPace: return "Wheelchair Walk"
        case .wheelchairRunPace: return "Wheelchair Run"
        case .handCycling: return "Hand Cycling"
        case .coreTraining: return "Core Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .highIntensityIntervalTraining: return "HIIT"
        case .jumpRope: return "Jump Rope"
        case .stairClimbing: return "Stair Climbing"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .fitnessGaming: return "Fitness Gaming"
        case .preparationAndRecovery: return "Recovery"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"

        // Studio activities
        case .barre: return "Barre"
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance"
        case .yoga: return "Yoga"
        case .mindAndBody: return "Mind and Body"
        case .pilates: return "Pilates"

        // Team sports
        case .americanFootball: return "American Football"
        case .australianFootball: return "Australian Football"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .cricket: return "Cricket"
        case .discSports: return "Disc Sports"
        case .handball: return "Handball"
        case .hockey: return "Hockey"
        case .lacrosse: return "Lacrosse"
        case .rugby: return "Rugby"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .volleyball: return "Volleyball"

        // Individual sports
        case .archery: return "Archery"
        case .bowling: return "Bowling"
        case .fencing: return "Fencing"
        case .gymnastics: return "Gymnastics"
        case .trackAndField: return "Track and Field"

        // Racket sports
        case .badminton: return "Badminton"
        case .pickleball: return "Pickleball"
        case .racquetball: return "Racquetball"
        case .squash: return "Squash"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"

        // Outdoor activities
        case .climbing: return "Climbing"
        case .equestrianSports: return "Equestrian"
        case .fishing: return "Fishing"
        case .golf: return "Golf"
        case .hunting: return "Hunting"
        case .play: return "Play"

        // Snow and ice sports
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .curling: return "Curling"
        case .downhillSkiing: return "Downhill Skiing"
        case .snowSports: return "Snow Sports"
        case .snowboarding: return "Snowboarding"
        case .skatingSports: return "Skating"

        // Water activities
        case .paddleSports: return "Paddle Sports"
        case .sailing: return "Sailing"
        case .surfingSports: return "Surfing"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .underwaterDiving: return "Underwater Diving"

        // Martial arts
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .martialArts: return "Martial Arts"
        case .taiChi: return "Tai Chi"
        case .wrestling: return "Wrestling"

        // Multisport
        case .swimBikeRun: return "Triathlon"
        case .transition: return "Transition"

        // Deprecated (but still supported)
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance Training"
        case .mixedMetabolicCardioTraining: return "Metabolic Cardio"

        // Other
        case .other: return "Other"

        @unknown default: return "Workout"
        }
    }

    /// Convert HKWeatherCondition to Entry format string
    private func weatherConditionString(_ condition: HKWeatherCondition) -> String {
        switch condition {
        case .none: return "unknown"
        case .clear: return "clear"
        case .fair: return "fair"
        case .partlyCloudy: return "partly_cloudy"
        case .mostlyCloudy: return "mostly_cloudy"
        case .cloudy: return "cloudy"
        case .foggy: return "foggy"
        case .haze: return "haze"
        case .windy: return "windy"
        case .blustery: return "blustery"
        case .smoky: return "smoky"
        case .dust: return "dust"
        case .snow: return "snow"
        case .hail: return "hail"
        case .sleet: return "sleet"
        case .freezingDrizzle: return "freezing_drizzle"
        case .freezingRain: return "freezing_rain"
        case .mixedRainAndHail: return "mixed_rain_hail"
        case .mixedRainAndSnow: return "mixed_rain_snow"
        case .mixedRainAndSleet: return "mixed_rain_sleet"
        case .mixedSnowAndSleet: return "mixed_snow_sleet"
        case .drizzle: return "drizzle"
        case .scatteredShowers: return "scattered_showers"
        case .showers: return "showers"
        case .thunderstorms: return "thunderstorms"
        case .tropicalStorm: return "tropical_storm"
        case .hurricane: return "hurricane"
        case .tornado: return "tornado"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case saveFailed
    case workoutNotFound
    case routeExtractionFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied. Please enable in Settings."
        case .saveFailed:
            return "Failed to save State of Mind to HealthKit"
        case .workoutNotFound:
            return "Workout not found in HealthKit"
        case .routeExtractionFailed:
            return "Failed to extract route data from workout"
        }
    }
}
