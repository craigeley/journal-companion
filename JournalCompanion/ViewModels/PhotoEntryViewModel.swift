//
//  PhotoEntryViewModel.swift
//  JournalCompanion
//
//  View model for photo entry creation with EXIF metadata extraction
//

import Foundation
import CoreLocation
import Combine
import HealthKit
import PhotosUI
import SwiftUI

@MainActor
class PhotoEntryViewModel: ObservableObject {
    // Core dependencies
    let vaultManager: VaultManager
    private let locationService: LocationService
    private let weatherService = WeatherService()
    private lazy var healthKitService = HealthKitService()

    // Photo selection
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var photoImage: UIImage?
    @Published var photoData: Data?
    @Published var photoEXIF: PhotoEXIF?
    @Published var isLoadingPhoto: Bool = false

    // Location & Weather
    @Published var currentLocation: CLLocation?
    @Published var weatherData: WeatherData?
    @Published var isFetchingWeather: Bool = false
    @Published var locationSource: LocationSource = .none

    // State of Mind
    @Published var moodData: StateOfMindData?
    @Published var showStateOfMindPicker: Bool = false
    @Published var tempMoodValence: Double = 0.0
    @Published var tempMoodLabels: [HKStateOfMind.Label] = []
    @Published var tempMoodAssociations: [HKStateOfMind.Association] = []

    // Entry metadata
    @Published var timestamp: Date = Date()
    @Published var tags: [String] = ["entry", "iPhone", "photo_entry"]
    @Published var selectedPlace: Place?
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false

    // Track initial values for staleness detection
    private var initialTimestamp: Date?
    private var initialLocation: CLLocation?
    private var weatherFetchedAt: Date?

    enum LocationSource {
        case none
        case exif
        case device
        case manual
    }

    var isValid: Bool {
        photoData != nil
    }

    init(vaultManager: VaultManager, locationService: LocationService) {
        self.vaultManager = vaultManager
        self.locationService = locationService
    }

    // MARK: - Photo Selection

    /// Handle photo selection from PhotosPicker
    func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            // Load photo data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load photo data"
                return
            }

            guard let image = UIImage(data: data) else {
                errorMessage = "Failed to create image from data"
                return
            }

            photoData = data
            photoImage = image

            // Extract EXIF metadata
            if let exif = EXIFExtractor.extractMetadata(from: data) {
                photoEXIF = exif

                // Auto-populate timestamp from EXIF
                if let exifTimestamp = exif.timestamp {
                    timestamp = exifTimestamp
                    initialTimestamp = exifTimestamp
                }

                // Auto-populate location from GPS
                if let coords = exif.location {
                    currentLocation = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
                    locationSource = .exif
                    initialLocation = currentLocation

                    // Try to match nearby place
                    selectedPlace = findMatchingPlace(for: currentLocation!)

                    // Fetch weather for photo's timestamp and location
                    await fetchWeather(for: currentLocation!, date: timestamp)
                }
            }

            print("✓ Loaded photo with EXIF: location=\(photoEXIF?.hasLocation ?? false), timestamp=\(photoEXIF?.hasTimestamp ?? false)")

        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
            print("❌ Photo loading error: \(error)")
        }
    }

    // MARK: - Location & Weather

    /// Detect current device location (fallback if no EXIF)
    func detectCurrentLocation() async {
        guard currentLocation == nil else { return }  // Don't override EXIF location

        currentLocation = await locationService.getCurrentLocation()
        if currentLocation != nil {
            locationSource = .device

            // Find matching place
            selectedPlace = findMatchingPlace(for: currentLocation!)

            // Fetch weather
            await fetchWeather(for: currentLocation!)
        }
    }

    /// Find a matching place within 100m radius
    private func findMatchingPlace(for location: CLLocation) -> Place? {
        let places = vaultManager.places

        for place in places {
            guard let placeCoords = place.location else { continue }

            let placeLocation = CLLocation(
                latitude: placeCoords.latitude,
                longitude: placeCoords.longitude
            )
            let distance = location.distance(from: placeLocation)

            if distance <= 100 {  // Within 100 meters
                print("✓ Matched place: \(place.name) (distance: \(Int(distance))m)")
                return place
            }
        }

        return nil
    }

    /// Fetch weather data for a location
    func fetchWeather(for location: CLLocation, date: Date? = nil) async {
        isFetchingWeather = true
        defer { isFetchingWeather = false }

        let weatherDate = date ?? timestamp

        do {
            let weather = try await weatherService.fetchWeather(for: location, date: weatherDate)
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
        await fetchWeather(for: location, date: timestamp)
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

    /// Create and save photo entry
    func createEntry() async {
        guard isValid else { return }
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }
        guard let photoData else {
            errorMessage = "No photo data"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            // Determine file extension
            let fileExtension = determineFileExtension(from: photoData)

            // Build entry content with photo placeholder
            let content = "![[PHOTO_PLACEHOLDER]]"

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
                content: content,
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

            // Add camera metadata to unknown fields (preserved in YAML)
            if let exif = photoEXIF {
                if let camera = exif.cameraModel {
                    entry.unknownFields["camera_model"] = .string(camera)
                    entry.unknownFieldsOrder.append("camera_model")
                }
                if let lens = exif.lensModel {
                    entry.unknownFields["lens_model"] = .string(lens)
                    entry.unknownFieldsOrder.append("lens_model")
                }
                if let focal = exif.focalLength {
                    // Store as integer mm (industry standard)
                    entry.unknownFields["focal_length"] = .int(Int(focal.rounded()))
                    entry.unknownFieldsOrder.append("focal_length")
                }
                if let aperture = exif.aperture {
                    // Round to 1 decimal place (industry standard for f-stops)
                    let roundedAperture = (aperture * 10).rounded() / 10
                    entry.unknownFields["aperture"] = .double(roundedAperture)
                    entry.unknownFieldsOrder.append("aperture")
                }
                if let iso = exif.iso {
                    entry.unknownFields["iso"] = .int(iso)
                    entry.unknownFieldsOrder.append("iso")
                }
            }

            // Save photo file
            let photoFileManager = PhotoFileManager(vaultURL: vaultURL)
            let filename = try await photoFileManager.writePhoto(
                data: photoData,
                for: entry,
                fileExtension: fileExtension
            )

            // Add photo attachment to unknown fields
            entry.unknownFields["photo_attachment"] = .string(filename)
            entry.unknownFieldsOrder.insert("photo_attachment", at: 0)

            // Replace placeholder with actual filename
            entry.content = entry.content.replacingOccurrences(
                of: "![[PHOTO_PLACEHOLDER]]",
                with: "![[photos/\(filename)]]"
            )

            // Write entry
            let writer = EntryWriter(vaultURL: vaultURL)
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

    /// Determine file extension from image data
    private func determineFileExtension(from data: Data) -> String {
        // Check magic bytes for image type
        let bytes = [UInt8](data.prefix(12))

        // JPEG: FF D8 FF
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpg"
        }

        // PNG: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }

        // HEIC: Check for 'ftyp' box with 'heic' or 'mif1' brand
        if bytes.count >= 12 {
            let ftypString = String(bytes: bytes[4..<8], encoding: .ascii)
            if ftypString == "ftyp" {
                let brandString = String(bytes: bytes[8..<12], encoding: .ascii)
                if brandString == "heic" || brandString == "mif1" || brandString == "heix" {
                    return "heic"
                }
            }
        }

        // Default to jpg
        return "jpg"
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

    /// Clear all data for a fresh start
    func reset() {
        selectedPhotoItem = nil
        photoImage = nil
        photoData = nil
        photoEXIF = nil
        currentLocation = nil
        locationSource = .none
        weatherData = nil
        moodData = nil
        timestamp = Date()
        selectedPlace = nil
        errorMessage = nil
        showSuccess = false
        initialTimestamp = nil
        initialLocation = nil
        weatherFetchedAt = nil
    }
}
