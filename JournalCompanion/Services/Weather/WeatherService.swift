//
//  WeatherService.swift
//  JournalCompanion
//
//  Fetches weather data using Apple's WeatherKit
//

import Foundation
import WeatherKit
import CoreLocation

struct WeatherData: Sendable {
    let temperature: Int  // Fahrenheit
    let condition: String
    let humidity: Int  // Percentage
    let aqi: Int?  // Air Quality Index (optional, may not be available)

    var conditionEmoji: String {
        switch condition.lowercased() {
        case let c where c.contains("clear"): return "☀️"
        case let c where c.contains("cloud"): return "☁️"
        case let c where c.contains("rain"): return "🌧️"
        case let c where c.contains("snow"): return "❄️"
        case let c where c.contains("storm"): return "⛈️"
        case let c where c.contains("fog"): return "🌫️"
        case let c where c.contains("wind"): return "💨"
        default: return "🌤️"
        }
    }
}

actor WeatherService {
    /// Fetch weather for a location at a specific date/time
    func fetchWeather(for location: CLLocation, date: Date = Date()) async throws -> WeatherData {
        let service = WeatherKit.WeatherService.shared

        // Determine if we need historical or current weather
        let now = Date()
        let timeDifference = now.timeIntervalSince(date)

        // If date is within 1 hour of now, use current weather
        // Otherwise, try to get hourly historical weather
        if abs(timeDifference) < 3600 {
            // Use current weather
            let weather = try await service.weather(for: location)
            let currentWeather = weather.currentWeather

            let tempF = Int(currentWeather.temperature.converted(to: .fahrenheit).value.rounded())
            let condition = currentWeather.condition.description
            let humidity = Int((currentWeather.humidity * 100).rounded())

            return WeatherData(
                temperature: tempF,
                condition: condition,
                humidity: humidity,
                aqi: nil
            )
        } else {
            // Try to get historical hourly weather
            // WeatherKit provides hourly forecasts and historical data
            let hourlyWeather = try await service.weather(
                for: location,
                including: .hourly(startDate: date, endDate: date.addingTimeInterval(3600))
            )

            // Get the first hour's weather (closest to requested time)
            guard let weatherHour = hourlyWeather.first else {
                throw NSError(domain: "WeatherService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No weather data available for this time"])
            }

            let tempF = Int(weatherHour.temperature.converted(to: .fahrenheit).value.rounded())
            let condition = weatherHour.condition.description
            let humidity = Int((weatherHour.humidity * 100).rounded())

            return WeatherData(
                temperature: tempF,
                condition: condition,
                humidity: humidity,
                aqi: nil
            )
        }
    }

    /// Fetch weather for coordinates
    func fetchWeather(latitude: Double, longitude: Double, date: Date = Date()) async throws -> WeatherData {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return try await fetchWeather(for: location, date: date)
    }
}
