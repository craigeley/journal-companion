//
//  PlaceMatcher.swift
//  JournalCompanion
//
//  Matches locations to places and calculates proximity
//

import Foundation
import CoreLocation

struct PlaceWithDistance: Identifiable {
    let place: Place
    let distance: CLLocationDistance // meters

    var id: String { place.id }

    var distanceFormatted: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let km = distance / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
}

class PlaceMatcher {
    private let proximityThreshold: CLLocationDistance = 5000 // 5km radius for "nearby"

    /// Find nearby places sorted by distance
    func findNearbyPlaces(from location: CLLocation, in places: [Place]) -> [PlaceWithDistance] {
        var placesWithDistances: [PlaceWithDistance] = []

        for place in places {
            guard let placeCoord = place.location else { continue }

            let placeLocation = CLLocation(
                latitude: placeCoord.latitude,
                longitude: placeCoord.longitude
            )

            let distance = location.distance(from: placeLocation)

            // Only include places within threshold
            if distance <= proximityThreshold {
                placesWithDistances.append(PlaceWithDistance(place: place, distance: distance))
            }
        }

        // Sort by distance (closest first)
        return placesWithDistances.sorted { $0.distance < $1.distance }
    }

    /// Find the closest place to a location
    func findClosestPlace(to location: CLLocation, in places: [Place]) -> PlaceWithDistance? {
        var closest: PlaceWithDistance?
        var minDistance = CLLocationDistance.infinity

        for place in places {
            guard let placeCoord = place.location else { continue }

            let placeLocation = CLLocation(
                latitude: placeCoord.latitude,
                longitude: placeCoord.longitude
            )

            let distance = location.distance(from: placeLocation)

            if distance < minDistance {
                minDistance = distance
                closest = PlaceWithDistance(place: place, distance: distance)
            }
        }

        return closest
    }
}
