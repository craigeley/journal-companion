//
//  AudioEntryViewModel.swift
//  JournalCompanion
//
//  View model for audio-only entry creation with metadata capture
//

import Foundation
import CoreLocation
import Combine
import HealthKit

@MainActor
class AudioEntryViewModel: ObservableObject {
    // Core dependencies
    let vaultManager: VaultManager
    private let locationService: LocationService
    private let weatherService = WeatherService()
    private lazy var healthKitService = HealthKitService()

    // Location & Weather
    @Published var currentLocation: CLLocation?
    @Published var weatherData: WeatherData?
    @Published var isFetchingWeather: Bool = false

    // State of Mind
    @Published var moodData: StateOfMindData?
    @Published var showStateOfMindPicker: Bool = false
    @Published var tempMoodValence: Double = 0.0
    @Published var tempMoodLabels: [HKStateOfMind.Label] = []
    @Published var tempMoodAssociations: [HKStateOfMind.Association] = []

    // Audio recording
    @Published var audioSegmentManager = AudioSegmentManager()
    @Published var showAudioRecordingSheet: Bool = false
    var recordingDeviceName: String?
    var recordingSampleRate: Int?
    var recordingBitDepth: Int?

    // Entry metadata
    @Published var timestamp: Date = Date()
    @Published var tags: [String] = ["entry", "iPhone", "audio_entry"]
    @Published var selectedPlace: Place?
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false

    // Audio format preference
    var audioFormat: AudioFormat {
        UserDefaults.standard.string(forKey: "audioFormat")
            .flatMap { AudioFormat(rawValue: $0) } ?? .aac
    }

    // Track initial values for staleness detection
    private var initialTimestamp: Date?
    private var initialLocation: CLLocation?
    private var weatherFetchedAt: Date?

    var isValid: Bool {
        audioSegmentManager.hasSegments
    }

    init(vaultManager: VaultManager, locationService: LocationService) {
        self.vaultManager = vaultManager
        self.locationService = locationService
    }

    // MARK: - Location & Weather

    /// Detect current location and fetch weather
    func detectCurrentLocation() async {
        currentLocation = await locationService.getCurrentLocation()

        // Fetch weather if we have a location
        if let location = currentLocation {
            await fetchWeather(for: location)
        }
    }

    /// Fetch weather data for a location
    func fetchWeather(for location: CLLocation) async {
        isFetchingWeather = true
        defer { isFetchingWeather = false }

        do {
            let weather = try await weatherService.fetchWeather(for: location, date: timestamp)
            weatherData = weather
            weatherFetchedAt = Date()

            // Track initial values for staleness detection
            if initialTimestamp == nil {
                initialTimestamp = timestamp
            }
            if initialLocation == nil {
                initialLocation = location
            }

            print("✓ Fetched weather: \(weather.temperature)°F, \(weather.condition)")
        } catch {
            print("❌ Failed to fetch weather: \(error)")
            // Don't show error to user - weather is optional
        }
    }

    /// Refresh weather data
    func refreshWeather() async {
        guard let location = currentLocation else { return }

        // Reset tracking to current values
        initialTimestamp = timestamp
        initialLocation = location

        // Fetch fresh weather
        await fetchWeather(for: location)
    }

    /// Check if weather data is stale
    var weatherIsStale: Bool {
        guard weatherData != nil else { return false }
        guard let initialTimestamp, let initialLocation else { return false }

        // Check if timestamp changed by more than 15 minutes
        let timeDiff = abs(timestamp.timeIntervalSince(initialTimestamp))
        let timestampChanged = timeDiff > 15 * 60

        // Check if location changed by more than 100 meters
        var locationChanged = false
        if let currentLocation {
            let distance = currentLocation.distance(from: initialLocation)
            locationChanged = distance > 100
        }

        return timestampChanged || locationChanged
    }

    // MARK: - State of Mind

    /// Open State of Mind picker
    func openStateOfMindPicker() {
        // Pre-populate if editing existing
        if let existingMood = moodData {
            tempMoodValence = existingMood.valence
            tempMoodLabels = convertToLabels(existingMood.labels)
            tempMoodAssociations = convertToAssociations(existingMood.associations)
        } else {
            tempMoodValence = 0.0
            tempMoodLabels = []
            tempMoodAssociations = []
        }
        showStateOfMindPicker = true
    }

    /// Save State of Mind selection from picker
    func saveStateOfMindSelection() {
        let labels = tempMoodLabels.map { StateOfMindConstants.displayName(for: $0) }
        let associations = tempMoodAssociations.map { StateOfMindConstants.displayName(for: $0) }
        moodData = StateOfMindData(valence: tempMoodValence, labels: labels, associations: associations)
    }

    /// Clear State of Mind data
    func clearStateOfMind() {
        moodData = nil
        tempMoodValence = 0.0
        tempMoodLabels = []
        tempMoodAssociations = []
    }

    // MARK: - Entry Creation

    /// Create and save audio entry
    func createEntry() async {
        guard isValid else { return }
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            // Build entry content with audio file links and transcriptions
            var combinedContent = "Audio journal entry."  // Placeholder

            // Add Obsidian file links and transcriptions for each segment
            if audioSegmentManager.hasSegments {
                let segments = audioSegmentManager.segments
                combinedContent = ""  // Clear placeholder

                for (index, segment) in segments.enumerated() {
                    // Add Obsidian file link (placeholder, will be replaced after saving)
                    combinedContent += "![[AUDIO_\(index)]]"

                    // Add transcription if available
                    if !segment.transcription.isEmpty {
                        combinedContent += "\n\n\(segment.transcription)"
                    }

                    // Add separator between segments
                    if index < segments.count - 1 {
                        combinedContent += "\n\n"
                    }
                }
            }

            // Format current location for YAML storage
            let locationString: String? = {
                if let loc = currentLocation {
                    return String(format: "%.5f,%.5f", loc.coordinate.latitude, loc.coordinate.longitude)
                }
                return nil
            }()

            var entry = Entry(
                id: UUID().uuidString,
                dateCreated: timestamp,
                tags: tags,
                place: selectedPlace?.name,
                people: [],
                placeCallout: selectedPlace?.callout,
                location: locationString,
                content: combinedContent,
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

            // Add weather data if available
            if let weather = weatherData {
                entry.temperature = weather.temperature
                entry.condition = weather.condition
                entry.humidity = weather.humidity
                entry.aqi = weather.aqi
            }

            // Add State of Mind data if available
            if let mood = moodData {
                entry.moodValence = mood.valence
                entry.moodLabels = mood.labels
                entry.moodAssociations = mood.associations
            }

            // Save audio segments
            let audioFileManager = AudioFileManager(vaultURL: vaultURL)
            let (filenames, _) = try await audioSegmentManager.saveSegments(
                for: entry,
                audioFileManager: audioFileManager
            )
            entry.audioAttachments = filenames
            entry.recordingDevice = recordingDeviceName
            entry.sampleRate = recordingSampleRate
            entry.bitDepth = recordingBitDepth

            // Mirror SRT transcripts to entry content (SRT is source of truth)
            let writer = EntryWriter(vaultURL: vaultURL)
            try await writer.mirrorTranscriptsToContent(
                entry: &entry,
                audioFileManager: audioFileManager
            )

            // Write entry
            try await writer.write(entry: entry)

            // Save State of Mind to HealthKit (non-fatal if fails)
            if let mood = moodData {
                let authStatus = await healthKitService.authorizationStatus()
                if authStatus == .sharingAuthorized {
                    do {
                        try await healthKitService.saveMood(
                            valence: mood.valence,
                            labels: tempMoodLabels,
                            associations: tempMoodAssociations,
                            date: entry.dateCreated
                        )
                        print("✓ Saved State of Mind to HealthKit")
                    } catch {
                        print("⚠️ Failed to save State of Mind to HealthKit: \(error)")
                    }
                } else {
                    print("ℹ️ HealthKit authorization not granted. State of Mind saved to markdown only.")
                }
            }

            showSuccess = true
            isCreating = false

        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }

    // MARK: - Helper Methods

    private func getAudioFileManager() -> AudioFileManager? {
        guard let vaultURL = vaultManager.vaultURL else { return nil }
        return AudioFileManager(vaultURL: vaultURL)
    }

    /// Convert string labels to HealthKit Label enums
    private func convertToLabels(_ strings: [String]) -> [HKStateOfMind.Label] {
        strings.compactMap { str in
            StateOfMindConstants.allLabels.first { $0.display == str }?.label
        }
    }

    /// Convert string associations to HealthKit Association enums
    private func convertToAssociations(_ strings: [String]) -> [HKStateOfMind.Association] {
        strings.compactMap { str in
            StateOfMindConstants.allAssociations.first { $0.display == str }?.association
        }
    }
}
