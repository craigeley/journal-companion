//
//  Entry.swift
//  JournalCompanion
//
//  Core data model for journal entries
//

import Foundation

// MARK: - YAML Value Types

/// Represents different types of YAML values for unknown fields
enum YAMLValue: Sendable, Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([String])
    case date(Date)

    var rawValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let a): return a
        case .date(let d): return d
        }
    }
}

// MARK: - Entry Model

struct Entry: Identifiable, Codable, Sendable {
    let id: String
    var dateCreated: Date
    var tags: [String]
    var place: String?  // Place name (without brackets)
    var people: [String]  // Array of person names (without brackets)
    var placeCallout: String?  // Place callout type (e.g., "cafe", "park", "home")
    var location: String?  // GPS coordinates in "latitude,longitude" format
    var content: String

    // Optional weather data
    var temperature: Int?
    var condition: String?
    var aqi: Int?
    var humidity: Int?

    // Optional State of Mind data
    var moodValence: Double?
    var moodLabels: [String]?
    var moodAssociations: [String]?

    // Audio attachments
    var audioAttachments: [String]?  // Array of filenames (time ranges stored in .srt sidecar files)
    var recordingDevice: String?  // Name of recording device (e.g., "iPhone Microphone")
    var sampleRate: Int?  // Sample rate in Hz (e.g., 48000)
    var bitDepth: Int?  // Bit depth for lossless formats (e.g., 24, 32)

    // Unknown YAML field preservation
    var unknownFields: [String: YAMLValue]
    var unknownFieldsOrder: [String]

    /// Generate filename in YYYYMMDDHHmm format
    nonisolated var filename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: dateCreated)
    }

    /// Generate directory path: Entries/YYYY/MM-Month/DD
    nonisolated var directoryPath: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: dateCreated)

        guard let year = components.year,
              let _ = components.month,
              let day = components.day else {
            return "Entries"
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM-MMMM"
        let monthString = monthFormatter.string(from: dateCreated)

        let dayString = String(format: "%02d", day)

        return "Entries/\(year)/\(monthString)/\(dayString)"
    }

    /// Convert entry to markdown format with YAML frontmatter
    /// Preserves unknown YAML fields in their original order
    nonisolated func toMarkdown() -> String {
        var yaml = "---\n"
        var writtenKnownFields = Set<String>()

        // Write fields in preserved order (known and unknown)
        for fieldKey in unknownFieldsOrder {
            if isKnownField(fieldKey) {
                writeKnownField(fieldKey, to: &yaml)
                writtenKnownFields.insert(fieldKey)
            } else {
                writeUnknownField(fieldKey, to: &yaml)
            }
        }

        // Write remaining known fields not in original order
        let knownFieldKeys = ["date_created", "tags", "place", "location", "temp", "cond",
                              "humidity", "aqi", "mood_valence", "mood_labels",
                              "mood_associations", "audio_attachments",
                              "recording_device", "sample_rate", "bit_depth"]
        for fieldKey in knownFieldKeys where !writtenKnownFields.contains(fieldKey) {
            writeKnownField(fieldKey, to: &yaml)
        }

        yaml += "---\n\n"
        return yaml + content + "\n"
    }

    private nonisolated func isKnownField(_ key: String) -> Bool {
        ["date_created", "tags", "place", "location", "people", "temp", "cond",
         "humidity", "aqi", "mood_valence", "mood_labels", "mood_associations",
         "audio_attachments", "recording_device", "sample_rate",
         "bit_depth"].contains(key)
    }

    private nonisolated func writeKnownField(_ key: String, to yaml: inout String) {
        switch key {
        case "date_created":
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone, .withFractionalSeconds]
            formatter.timeZone = TimeZone.current
            yaml += "date_created: \(formatter.string(from: dateCreated))\n"

        case "tags":
            if !tags.isEmpty {
                yaml += "tags:\n"
                for tag in tags {
                    yaml += "  - \(tag)\n"
                }
            }

        case "place":
            if let place = place, !place.isEmpty {
                yaml += "place: \"[[\(place)]]\"\n"
            }

        case "location":
            if let loc = location, !loc.isEmpty {
                yaml += "location: \(loc)\n"
            }

        case "temp":
            if let temp = temperature {
                yaml += "temp: \(temp)\n"
            }

        case "cond":
            if let cond = condition {
                yaml += "cond: \(cond)\n"
            }

        case "humidity":
            if let h = humidity {
                yaml += "humidity: \(h)\n"
            }

        case "aqi":
            if let a = aqi {
                yaml += "aqi: \(a)\n"
            }

        case "mood_valence":
            if let mv = moodValence {
                // Round to 1 decimal place for readability
                yaml += "mood_valence: \(String(format: "%.1f", mv))\n"
            }

        case "mood_labels":
            if let labels = moodLabels, !labels.isEmpty {
                yaml += "mood_labels:\n"
                for label in labels {
                    yaml += "  - \(label)\n"
                }
            }

        case "mood_associations":
            if let assocs = moodAssociations, !assocs.isEmpty {
                yaml += "mood_associations:\n"
                for assoc in assocs {
                    yaml += "  - \(assoc)\n"
                }
            }

        case "audio_attachments":
            if let attachments = audioAttachments, !attachments.isEmpty {
                yaml += "audio_attachments:\n"
                for filename in attachments {
                    yaml += "  - \(filename)\n"
                }
            }

        case "recording_device":
            if let device = recordingDevice, !device.isEmpty {
                yaml += "recording_device: \"\(device)\"\n"
            }

        case "sample_rate":
            if let rate = sampleRate {
                yaml += "sample_rate: \(rate)\n"
            }

        case "bit_depth":
            if let depth = bitDepth {
                yaml += "bit_depth: \(depth)\n"
            }

        default:
            break
        }
    }

    private nonisolated func writeUnknownField(_ key: String, to yaml: inout String) {
        guard let value = unknownFields[key] else { return }

        switch value {
        case .string(let s):
            yaml += "\(key): \(s)\n"
        case .int(let i):
            yaml += "\(key): \(i)\n"
        case .double(let d):
            // Format doubles cleanly: use 1 decimal for aperture-like values,
            // remove unnecessary trailing zeros for others
            if key == "aperture" {
                yaml += "\(key): \(String(format: "%.1f", d))\n"
            } else if d == d.rounded() {
                // Whole number - write as integer
                yaml += "\(key): \(Int(d))\n"
            } else {
                // Use up to 2 decimal places, trimming trailing zeros
                let formatted = String(format: "%.2f", d)
                    .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                yaml += "\(key): \(formatted)\n"
            }
        case .bool(let b):
            yaml += "\(key): \(b)\n"
        case .array(let arr):
            yaml += "\(key):\n"
            for item in arr {
                yaml += "  - \(item)\n"
            }
        case .date(let d):
            let formatter = ISO8601DateFormatter()
            yaml += "\(key): \(formatter.string(from: d))\n"
        }
    }

    /// Create a new entry with current timestamp
    static func create(content: String, place: String? = nil, people: [String] = [], location: String? = nil, tags: [String] = ["entry", "iPhone"]) -> Entry {
        Entry(
            id: UUID().uuidString,
            dateCreated: Date(),
            tags: tags,
            place: place,
            people: people,
            placeCallout: nil,
            location: location,
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
    }
}

// MARK: - Validation
extension Entry {
    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - People Extraction
extension Entry {
    /// Extract people names from wiki-links in entry content
    /// Returns array of person names found in valid [[...]] links
    func extractPeople(from peopleList: [Person]) -> [String] {
        WikiLinkParser.extractPeopleNames(from: content, people: peopleList)
    }
}

// MARK: - Workout Entry Support
extension Entry {
    /// Check if this entry represents any workout
    var isWorkoutEntry: Bool {
        tags.contains("workout") || tags.contains("running") ||
        tags.contains("cycling") || tags.contains("walking")
    }

    /// Check if this entry represents a running workout
    var isRunningEntry: Bool {
        tags.contains("running")
    }

    /// Workout type (from unknownFields)
    nonisolated var workoutType: String? {
        guard let value = unknownFields["workout_type"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Calories burned (from unknownFields)
    nonisolated var calories: Int? {
        guard let value = unknownFields["calories"] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    /// HealthKit workout UUID (for duplicate detection)
    nonisolated var healthKitWorkoutID: String? {
        guard let value = unknownFields["healthkit_workout_id"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// GPX route filename reference (from unknownFields)
    nonisolated var routeFile: String? {
        guard let value = unknownFields["route_file"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Running distance in miles (from unknownFields)
    nonisolated var distance: Double? {
        guard let value = unknownFields["distance"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .string(let s):
            return Double(s)
        case .int(let i):
            return Double(i)
        default:
            return nil
        }
    }

    /// Running time in MM:SS format (from unknownFields)
    nonisolated var time: String? {
        guard let value = unknownFields["time"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Running pace in MM:SS format (from unknownFields)
    nonisolated var pace: String? {
        guard let value = unknownFields["pace"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Average cadence in steps per minute (from unknownFields)
    nonisolated var avgCadence: Int? {
        guard let value = unknownFields["avg_cadence"] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    /// Average heart rate in beats per minute (from unknownFields)
    nonisolated var avgHeartRate: Int? {
        guard let value = unknownFields["avg_hr"] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    /// Average power in watts (from unknownFields)
    nonisolated var avgPower: Int? {
        guard let value = unknownFields["avg_power"] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }

    /// Average ground contact time in milliseconds (from unknownFields)
    nonisolated var avgStanceTime: Double? {
        guard let value = unknownFields["avg_stance_time"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    /// Average step length in millimeters (from unknownFields)
    nonisolated var avgStepLength: Double? {
        guard let value = unknownFields["avg_step_length"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    /// Average vertical oscillation in millimeters (from unknownFields)
    nonisolated var avgVerticalOscillation: Double? {
        guard let value = unknownFields["avg_vertical_oscillation"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    /// Average vertical ratio as percentage (from unknownFields)
    nonisolated var avgVerticalRatio: Double? {
        guard let value = unknownFields["avg_vertical_ratio"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    /// Total strides (from unknownFields)
    nonisolated var totalStrides: Int? {
        guard let value = unknownFields["total_strides"] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        case .string(let s):
            return Int(s)
        default:
            return nil
        }
    }
}

// MARK: - Photo Entry Support
extension Entry {
    /// Check if this entry represents a photo entry
    var isPhotoEntry: Bool {
        tags.contains("photo_entry") || photoAttachment != nil
    }

    /// Photo attachment filename (from unknownFields)
    nonisolated var photoAttachment: String? {
        guard let value = unknownFields["photo_attachment"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Camera model (from unknownFields)
    nonisolated var cameraModel: String? {
        guard let value = unknownFields["camera_model"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Lens model (from unknownFields)
    nonisolated var lensModel: String? {
        guard let value = unknownFields["lens_model"] else { return nil }

        switch value {
        case .string(let s):
            return s
        default:
            return nil
        }
    }

    /// Focal length in mm (from unknownFields)
    nonisolated var focalLength: Double? {
        guard let value = unknownFields["focal_length"] else { return nil }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }
}

// MARK: - Attachment Detection
extension Entry {
    /// Check if entry has any attachments (audio, photo, GPX routes, or maps)
    nonisolated var hasAttachments: Bool {
        // Check for audio attachments
        if let audioFiles = audioAttachments, !audioFiles.isEmpty {
            return true
        }

        // Check for photo attachment
        if photoAttachment != nil {
            return true
        }

        // Check for GPX route file
        if routeFile != nil {
            return true
        }

        return false
    }

    /// List of attachment types present
    nonisolated var attachmentTypes: [String] {
        var types: [String] = []

        if let audioFiles = audioAttachments, !audioFiles.isEmpty {
            types.append("\(audioFiles.count) audio file\(audioFiles.count == 1 ? "" : "s")")
        }

        if photoAttachment != nil {
            types.append("photo")
        }

        if routeFile != nil {
            types.append("GPX route and map")
        }

        return types
    }
}
