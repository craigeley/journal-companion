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
        case "cafe", "restaurant": return "cup.and.saucer.fill"
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
        default: return "mappin.circle.fill"
        }
    }

    static func color(for callout: String) -> Color {
        switch callout.lowercased() {
        case "school": return .blue
        case "park": return .green
        case "cafe", "restaurant": return .orange
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
        default: return .blue
        }
    }
}
