//
//  DailyNoteManager.swift
//  JournalCompanion
//
//  Manages daily note files in Days/ directory
//  Updates YAML frontmatter with weather metadata
//

import Foundation
import CoreLocation

actor DailyNoteManager {
    private let vaultURL: URL
    private let fileManager = FileManager.default
    private let weatherService = DailyWeatherService()

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Get the file URL for a given date's day note
    func dayFileURL(for date: Date) -> URL {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)

        guard let year = components.year else {
            fatalError("Invalid date: cannot extract year")
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM-MMMM"
        let monthString = monthFormatter.string(from: date)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dayFilename = dayFormatter.string(from: date) + ".md"

        let dayDir = vaultURL.appendingPathComponent("Days/\(year)/\(monthString)")
        return dayDir.appendingPathComponent(dayFilename)
    }

    /// Check if a day file exists
    func dayFileExists(for date: Date) -> Bool {
        let url = dayFileURL(for: date)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Read the content of a day file
    func readDayFile(for date: Date) throws -> String? {
        let url = dayFileURL(for: date)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Check if a day file has minimal/empty YAML frontmatter
    func hasMinimalYAML(_ content: String) -> Bool {
        // Check if content starts with minimal YAML (just empty frontmatter)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("---\n---") || trimmed.hasPrefix("---\r\n---")
    }

    /// Update day file with weather metadata
    /// Only updates files with minimal YAML frontmatter
    func updateWithWeatherMetadata(
        for date: Date,
        location: CLLocation
    ) async throws {
        let url = dayFileURL(for: date)

        guard let content = try readDayFile(for: date) else {
            print("⚠️ Day file does not exist for \(date)")
            return
        }

        // Only update if it has minimal YAML
        guard hasMinimalYAML(content) else {
            print("⏭️ Day file already has metadata, skipping")
            return
        }

        // Fetch weather data
        let forecast = try await weatherService.fetchDailyForecast(for: date, location: location)

        // Build new YAML frontmatter
        let yaml = """
        ---
        low_temp: \(forecast.lowTemp)
        high_temp: \(forecast.highTemp)
        sunrise: \(forecast.sunrise)
        sunset: \(forecast.sunset)
        ---
        """

        // Replace the minimal YAML with full metadata
        let updatedContent = content.replacingOccurrences(
            of: "^---\\s*\\n---",
            with: yaml,
            options: .regularExpression
        )

        // Write back to file
        try updatedContent.write(to: url, atomically: true, encoding: .utf8)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dayString = dayFormatter.string(from: date)
        print("✓ Updated day file with weather metadata: \(dayString).md")
    }

    /// Scan all day files and update those with minimal YAML
    /// Returns count of updated files
    func updateAllDayFilesWithWeatherMetadata(location: CLLocation) async throws -> Int {
        let daysDir = vaultURL.appendingPathComponent("Days")

        guard fileManager.fileExists(atPath: daysDir.path) else {
            print("⚠️ Days directory does not exist")
            return 0
        }

        var updatedCount = 0

        // Enumerate all year directories
        let yearDirs = try fileManager.contentsOfDirectory(
            at: daysDir,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }

        for yearDir in yearDirs {
            // Enumerate all month directories
            let monthDirs = try fileManager.contentsOfDirectory(
                at: yearDir,
                includingPropertiesForKeys: nil
            ).filter { $0.hasDirectoryPath }

            for monthDir in monthDirs {
                // Enumerate all day files
                let dayFiles = try fileManager.contentsOfDirectory(
                    at: monthDir,
                    includingPropertiesForKeys: nil
                ).filter { $0.pathExtension == "md" }

                for dayFile in dayFiles {
                    // Parse date from filename (yyyy-MM-dd.md)
                    let filename = dayFile.deletingPathExtension().lastPathComponent

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"

                    guard let date = dateFormatter.date(from: filename) else {
                        print("⚠️ Could not parse date from filename: \(filename)")
                        continue
                    }

                    // Try to update this day file
                    do {
                        let content = try String(contentsOf: dayFile, encoding: .utf8)

                        if hasMinimalYAML(content) {
                            try await updateWithWeatherMetadata(for: date, location: location)
                            updatedCount += 1
                        }
                    } catch {
                        print("⚠️ Error processing \(filename): \(error)")
                        continue
                    }
                }
            }
        }

        print("✓ Updated \(updatedCount) day files with weather metadata")
        return updatedCount
    }

    /// Create or update day file YAML when creating a new entry
    /// Used by EntryWriter to populate metadata for new day files
    func ensureDayFileHasMetadata(
        for date: Date,
        location: CLLocation
    ) async throws -> String {
        // If file doesn't exist yet, return YAML with metadata for EntryWriter to use
        if !dayFileExists(for: date) {
            let forecast = try await weatherService.fetchDailyForecast(for: date, location: location)

            return """
            ---
            low_temp: \(forecast.lowTemp)
            high_temp: \(forecast.highTemp)
            sunrise: \(forecast.sunrise)
            sunset: \(forecast.sunset)
            ---
            """
        } else {
            // File exists - update it if needed
            try await updateWithWeatherMetadata(for: date, location: location)
            return ""  // Empty string means file already exists
        }
    }
}
