//
//  PlaceIconProvider.swift
//  JournalCompanion
//
//  Shared place icon and color mappings
//

import SwiftUI
import MapKit

enum PlaceIcon {
    static func systemName(for callout: String) -> String {
        switch callout.lowercased() {
        case "school": return "graduationcap.fill"
        case "park": return "tree.fill"
        case "cafe": return "cup.and.saucer.fill"
        case "restaurant": return "fork.knife"
        case "grocery": return "cart.fill"
        case "home", "residence": return "house.fill"
        case "bar": return "wineglass.fill"
        case "shop": return "bag.fill"
        case "medical": return "cross.case.fill"
        case "airport": return "airplane"
        case "hotel": return "bed.double.fill"
        case "library": return "books.vertical.fill"
        case "zoo": return "pawprint.fill"
        case "museum": return "building.columns.fill"
        case "workout": return "figure.run"
        case "concert": return "music.note"
        case "entertainment": return "theatermasks.fill"
        case "movie": return "film.fill"
        case "service": return "wrench.and.screwdriver.fill"
        default: return "mappin.circle.fill"
        }
    }

    static func color(for callout: String) -> Color {
        switch callout.lowercased() {
        case "school": return .blue
        case "park": return .green
        case "cafe": return .brown
        case "restaurant": return .orange
        case "grocery": return .green.opacity(0.8)
        case "home", "residence": return .purple
        case "bar": return .red
        case "shop": return .pink
        case "medical": return .red
        case "airport": return .blue
        case "hotel": return .indigo
        case "library": return .brown
        case "zoo": return .orange
        case "museum": return .gray
        case "workout": return .orange
        case "concert": return .purple
        case "entertainment": return .pink
        case "movie": return .indigo
        case "service": return .gray
        default: return .blue
        }
    }

    /// Maps MapKit point of interest category to app callout type
    /// Returns nil for unmapped categories (triggers fallback to template default)
    static func calloutType(from category: MKPointOfInterestCategory?) -> String? {
        guard let category = category else { return nil }

        switch category {
        // Direct mappings to app's 20 callout types
        case .airport: return "airport"
        case .cafe: return "cafe"
        case .restaurant: return "restaurant"
        case .park, .nationalPark: return "park"
        case .school, .university: return "school"
        case .hospital, .pharmacy: return "medical"
        case .hotel: return "hotel"
        case .library: return "library"
        case .zoo, .aquarium: return "zoo"
        case .museum, .planetarium: return "museum"
        case .fitnessCenter: return "workout"
        case .theater, .movieTheater: return "movie"
        case .nightlife, .brewery, .winery: return "bar"
        case .store, .bakery: return "shop"
        case .foodMarket: return "grocery"
        case .musicVenue, .stadium: return "concert"
        case .amusementPark, .fairground, .goKart, .miniGolf: return "entertainment"

        // Service-related POIs → "service"
        case .atm, .bank, .carRental, .evCharger, .gasStation,
             .laundry, .parking, .postOffice, .publicTransport,
             .automotiveRepair, .fireStation, .police:
            return "service"

        // Unmapped categories return nil → falls back to template default
        default: return nil
        }
    }
}
