//
//  MediaIconProvider.swift
//  JournalCompanion
//
//  Provides consistent icons and colors for media types
//

import SwiftUI

enum MediaIcon {
    /// Get SF Symbol name for a media type
    static func systemName(for type: MediaType) -> String {
        type.systemImage
    }

    /// Get SF Symbol name for a media type string
    static func systemName(for typeString: String) -> String {
        guard let type = MediaType(rawValue: typeString) else {
            return "questionmark.square"
        }
        return type.systemImage
    }

    /// Get color for a media type
    static func color(for type: MediaType) -> Color {
        type.color
    }

    /// Get color for a media type string
    static func color(for typeString: String) -> Color {
        guard let type = MediaType(rawValue: typeString) else {
            return .gray
        }
        return type.color
    }

    /// Get all media type options for picker
    static var allTypes: [MediaType] {
        MediaType.allCases
    }
}
