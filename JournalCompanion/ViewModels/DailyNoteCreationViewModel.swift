//
//  DailyNoteCreationViewModel.swift
//  JournalCompanion
//
//  Manages creating daily notes for specific dates
//

import Foundation
import SwiftUI
import CoreLocation

@MainActor
class DailyNoteCreationViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var dayFileExists = false

    let vaultManager: VaultManager

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
        checkDayFileExists()
    }

    func checkDayFileExists() {
        guard let vaultURL = vaultManager.vaultURL else {
            dayFileExists = false
            return
        }

        let manager = DailyNoteManager(vaultURL: vaultURL)
        Task {
            let exists = await manager.dayFileExists(for: selectedDate)
            await MainActor.run {
                self.dayFileExists = exists
            }
        }
    }

    func createDailyNote() async -> Bool {
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return false
        }

        isCreating = true
        errorMessage = nil
        successMessage = nil
        defer { isCreating = false }

        do {
            // Check if file already exists
            let manager = DailyNoteManager(vaultURL: vaultURL)
            if await manager.dayFileExists(for: selectedDate) {
                errorMessage = "Daily note already exists for this date"
                return false
            }

            // Create the day file directory structure
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: selectedDate)
            guard let year = components.year else {
                errorMessage = "Invalid date"
                return false
            }

            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MM-MMMM"
            let monthString = monthFormatter.string(from: selectedDate)

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let dayFilename = dayFormatter.string(from: selectedDate) + ".md"

            let dayDir = vaultURL.appendingPathComponent("Days/\(year)/\(monthString)")
            let dayFileURL = dayDir.appendingPathComponent(dayFilename)

            // Create directory if needed
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: dayDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Fetch weather metadata if location is set
            let yamlHeader = await fetchWeatherMetadata(for: selectedDate)

            // Create the day file content
            let content = """
            \(yamlHeader)

            ### Entries

            """

            // Write the file
            try content.write(to: dayFileURL, atomically: true, encoding: .utf8)

            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            successMessage = "Created daily note for \(displayFormatter.string(from: selectedDate))"
            dayFileExists = true

            print("✓ Created daily note: \(dayFilename)")
            return true

        } catch {
            errorMessage = "Failed to create daily note: \(error.localizedDescription)"
            print("❌ Failed to create daily note: \(error)")
            return false
        }
    }

    private func fetchWeatherMetadata(for date: Date) async -> String {
        // Read weather location from UserDefaults
        let weatherLat = UserDefaults.standard.double(forKey: "dailyNoteWeatherLatitude")
        let weatherLon = UserDefaults.standard.double(forKey: "dailyNoteWeatherLongitude")

        // If no location set (both are 0.0), return minimal YAML
        guard weatherLat != 0.0 && weatherLon != 0.0 else {
            return "---\n---"
        }

        // Try to fetch weather data
        do {
            let weatherService = DailyWeatherService()
            let location = CLLocation(latitude: weatherLat, longitude: weatherLon)
            let forecast = try await weatherService.fetchDailyForecast(for: date, location: location)

            // Return YAML with weather metadata
            return """
            ---
            low_temp: \(forecast.lowTemp)
            high_temp: \(forecast.highTemp)
            sunrise: \(forecast.sunrise)
            sunset: \(forecast.sunset)
            ---
            """
        } catch {
            // If weather fetch fails, fall back to minimal YAML
            print("⚠️ Weather fetch failed (non-fatal): \(error)")
            return "---\n---"
        }
    }
}
