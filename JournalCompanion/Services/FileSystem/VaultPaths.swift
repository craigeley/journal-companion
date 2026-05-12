//
//  VaultPaths.swift
//  JournalCompanion
//
//  Central configuration for vault subfolder paths.
//
//  Currently hardcoded to a flat layout (everything at root) except
//  `_attachments`, which holds binary HealthKit data (GPX routes,
//  workout map snapshots) and other binary attachments (audio, photos).
//
//  Designed to be made user-configurable in the future without changing
//  call sites: writers/readers always resolve paths through this struct.
//

import Foundation

enum VaultCategory: String, CaseIterable, Sendable {
    case entries
    case places
    case people
    case media
    case attachments
}

// VaultPaths is pure data + pure functions. Marking everything nonisolated
// lets actors (PlaceReader, VaultMigrator, etc.) call into it from any context.
nonisolated struct VaultPaths {
    /// Folder for journal entries. Empty string = vault root.
    static let entries: String = ""

    /// Folder for place notes. Empty string = vault root.
    static let places: String = ""

    /// Folder for people notes. Empty string = vault root.
    static let people: String = ""

    /// Folder for media notes. Empty string = vault root.
    static let media: String = ""

    /// Folder for binary attachments (audio, photos, GPX routes, map snapshots).
    /// Kept nested to avoid hundreds of binary files at the vault root.
    static let attachments: String = "_attachments"

    // MARK: - Legacy paths (used by readers to discover pre-migration files)

    static let legacyEntries: String = "Entries"
    static let legacyPlaces: String = "Places"
    static let legacyPeople: String = "People"
    static let legacyMedia: String = "Media"

    // MARK: - Resolution

    /// Resolve a category path to an absolute URL within a vault.
    /// An empty path resolves to the vault root itself.
    static func url(for category: VaultCategory, in vaultURL: URL) -> URL {
        let path = self.path(for: category)
        return path.isEmpty ? vaultURL : vaultURL.appendingPathComponent(path)
    }

    static func path(for category: VaultCategory) -> String {
        switch category {
        case .entries: return entries
        case .places: return places
        case .people: return people
        case .media: return media
        case .attachments: return attachments
        }
    }

    /// Legacy URL for a category (returns nil for categories without a legacy folder).
    static func legacyURL(for category: VaultCategory, in vaultURL: URL) -> URL? {
        switch category {
        case .entries: return vaultURL.appendingPathComponent(legacyEntries)
        case .places: return vaultURL.appendingPathComponent(legacyPlaces)
        case .people: return vaultURL.appendingPathComponent(legacyPeople)
        case .media: return vaultURL.appendingPathComponent(legacyMedia)
        case .attachments: return nil
        }
    }
}
