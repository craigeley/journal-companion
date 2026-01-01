//
//  DailyWeatherService.swift
//  JournalCompanion
//
//  Fetches daily forecast data for day note metadata
//

import Foundation
import WeatherKit
import CoreLocation

struct DailyForecast: Sendable {
    let lowTemp: Int      // Fahrenheit
    let highTemp: Int     // Fahrenheit
    let sunrise: String   // Formatted time (e.g., "7:28 AM")
    let sunset: String    // Formatted time (e.g., "4:28 PM")
}

actor DailyWeatherService {
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Fetch daily forecast for a specific date
    /// Uses vault location or falls back to user's current location
    func fetchDailyForecast(for date: Date, location: CLLocation) async throws -> DailyForecast {
        let service = WeatherKit.WeatherService.shared

        // Get the day's weather forecast
        // Create a date range for the full day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch daily weather
        let dailyWeather = try await service.weather(
            for: location,
            including: .daily(startDate: startOfDay, endDate: endOfDay)
        )

        // Get the first day's forecast
        guard let dayForecast = dailyWeather.first else {
            throw DailyWeatherError.noForecastAvailable
        }

        // Convert temperatures to Fahrenheit
        let lowTempF = Int(dayForecast.lowTemperature.converted(to: .fahrenheit).value.rounded())
        let highTempF = Int(dayForecast.highTemperature.converted(to: .fahrenheit).value.rounded())

        // Format sunrise/sunset times
        let sunriseString = timeFormatter.string(from: dayForecast.sun.sunrise!)
        let sunsetString = timeFormatter.string(from: dayForecast.sun.sunset!)

        return DailyForecast(
            lowTemp: lowTempF,
            highTemp: highTempF,
            sunrise: sunriseString,
            sunset: sunsetString
        )
    }

    /// Fetch daily forecast using coordinates
    func fetchDailyForecast(for date: Date, latitude: Double, longitude: Double) async throws -> DailyForecast {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return try await fetchDailyForecast(for: date, location: location)
    }
}

// MARK: - Errors
enum DailyWeatherError: LocalizedError {
    case noForecastAvailable

    var errorDescription: String? {
        switch self {
        case .noForecastAvailable:
            return "No weather forecast available for this date"
        }
    }
}
