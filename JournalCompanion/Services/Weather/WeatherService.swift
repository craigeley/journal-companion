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
    /// Fetch current weather for a location
    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        // Get current weather from WeatherKit
        let service = WeatherKit.WeatherService.shared
        let weather = try await service.weather(for: location)

        let currentWeather = weather.currentWeather

        // Convert temperature to Fahrenheit and round
        let tempF = Int(currentWeather.temperature.converted(to: .fahrenheit).value.rounded())

        // Get condition description
        let condition = currentWeather.condition.description

        // Get humidity percentage
        let humidity = Int((currentWeather.humidity * 100).rounded())

        // Note: WeatherKit doesn't directly expose AQI in a simple way
        // Air quality data requires additional API calls and is region-dependent
        // Setting to nil for now - can be enhanced later
        let aqi: Int? = nil

        return WeatherData(
            temperature: tempF,
            condition: condition,
            humidity: humidity,
            aqi: aqi
        )
    }

    /// Fetch weather for coordinates
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return try await fetchWeather(for: location)
    }
}
