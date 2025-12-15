//
//  PlaceIconProvider.swift
//  JournalCompanion
//
//  Shared place icon and color mappings
//

import SwiftUI

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
}
