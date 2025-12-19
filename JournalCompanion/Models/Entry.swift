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
    var audioAttachments: [String]?  // Array of filenames
    var audioTimeRanges: [String]?  // Encoded time ranges for playback
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
        let knownFieldKeys = ["date_created", "tags", "place", "temp", "cond",
                              "humidity", "aqi", "mood_valence", "mood_labels",
                              "mood_associations", "audio_attachments", "audio_time_ranges",
                              "recording_device", "sample_rate", "bit_depth"]
        for fieldKey in knownFieldKeys where !writtenKnownFields.contains(fieldKey) {
            writeKnownField(fieldKey, to: &yaml)
        }

        yaml += "---\n\n"
        return yaml + content + "\n"
    }

    private nonisolated func isKnownField(_ key: String) -> Bool {
        ["date_created", "tags", "place", "people", "temp", "cond",
         "humidity", "aqi", "mood_valence", "mood_labels", "mood_associations",
         "audio_attachments", "audio_time_ranges", "recording_device", "sample_rate",
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
                yaml += "mood_valence: \(mv)\n"
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

        case "audio_time_ranges":
            if let ranges = audioTimeRanges, !ranges.isEmpty {
                yaml += "audio_time_ranges:\n"
                for range in ranges {
                    yaml += "  - \"\(range)\"\n"
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
            yaml += "\(key): \(d)\n"
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
    static func create(content: String, place: String? = nil, people: [String] = [], tags: [String] = ["entry", "iPhone"]) -> Entry {
        Entry(
            id: UUID().uuidString,
            dateCreated: Date(),
            tags: tags,
            place: place,
            people: people,
            placeCallout: nil,
            content: content,
            temperature: nil,
            condition: nil,
            aqi: nil,
            humidity: nil,
            moodValence: nil,
            moodLabels: nil,
            moodAssociations: nil,
            audioAttachments: nil,
            audioTimeRanges: nil,
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
