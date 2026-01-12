//
//  MediaEditViewModel.swift
//  JournalCompanion
//
//  View model for creating and editing media entries
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MediaEditViewModel: ObservableObject, Identifiable {
    // Editable fields
    @Published var title: String = ""
    @Published var mediaType: MediaType = .movie
    @Published var creator: String = ""
    @Published var releaseYear: String = ""
    @Published var genre: String = ""
    @Published var artworkURL: String = ""
    @Published var iTunesURL: String = ""
    @Published var tags: [String] = []
    @Published var aliases: [String] = []
    @Published var content: String = ""  // Notes/review

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var titleError: String?

    // Newly created media (set after successful creation)
    @Published var createdMedia: Media?

    private let originalMedia: Media?
    private let initialSearchResult: iTunesSearchItem?
    let vaultManager: VaultManager

    var isCreating: Bool { originalMedia == nil }

    /// Initialize for creating new media from iTunes search result
    init(
        vaultManager: VaultManager,
        searchResult: iTunesSearchItem,
        mediaType: MediaType
    ) {
        self.vaultManager = vaultManager
        self.originalMedia = nil
        self.initialSearchResult = searchResult

        // Pre-populate from search result
        self.title = searchResult.displayTitle
        self.mediaType = mediaType
        self.creator = searchResult.displayCreator ?? ""
        self.releaseYear = searchResult.releaseYear.map { String($0) } ?? ""
        self.genre = searchResult.primaryGenreName ?? searchResult.genres?.first ?? ""
        self.artworkURL = searchResult.displayArtworkURL ?? ""
        self.iTunesURL = searchResult.displayURL ?? ""

        // Build tags including genres (filter out generic terms like "Books" and sanitize)
        var tags = ["media", mediaType.rawValue]
        if let genres = searchResult.genres {
            let filteredGenres = genres.compactMap { genre -> String? in
                let lowercased = genre.lowercased()
                if lowercased == "books" || lowercased == "ebooks" {
                    return nil
                }
                return Media.sanitizeTag(genre)
            }.filter { !$0.isEmpty }
            tags.append(contentsOf: filteredGenres)
        }
        self.tags = tags

        self.aliases = []
        self.content = ""
    }

    /// Initialize for editing existing media
    init(
        vaultManager: VaultManager,
        media: Media
    ) {
        self.vaultManager = vaultManager
        self.originalMedia = media
        self.initialSearchResult = nil

        // Pre-populate from existing media
        self.title = media.title
        self.mediaType = media.mediaType
        self.creator = media.creator ?? ""
        self.releaseYear = media.releaseYear.map { String($0) } ?? ""
        self.genre = media.genre ?? ""
        self.artworkURL = media.artworkURL ?? ""
        self.iTunesURL = media.iTunesURL ?? ""
        self.tags = media.tags
        self.aliases = media.aliases
        self.content = media.content
    }

    /// Validation - title is required and must not conflict
    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Title required
        guard !trimmedTitle.isEmpty else {
            return false
        }

        if isCreating {
            // Check for duplicate
            let sanitized = Media.sanitizeFilename(trimmedTitle)
            let exists = vaultManager.media.contains { $0.id == sanitized }
            return !exists
        }

        return true
    }

    /// Update validation error message
    func validateTitle() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            titleError = "Title is required"
            return
        }

        if isCreating {
            let sanitized = Media.sanitizeFilename(trimmedTitle)
            let exists = vaultManager.media.contains { $0.id == sanitized }

            if exists {
                titleError = "Media with this title already exists"
            } else {
                titleError = nil
            }
        } else {
            titleError = nil
        }
    }

    /// Save media entry
    func save() async -> Bool {
        guard isValid else { return false }
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            let writer = MediaWriter(vaultURL: vaultURL)

            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedId = isCreating ? Media.sanitizeFilename(trimmedTitle) : originalMedia!.id

            // Build unknown fields from search result or original
            var unknownFields: [String: YAMLValue] = [:]
            var unknownFieldsOrder: [String] = []

            if isCreating, let result = initialSearchResult {
                // Copy type-specific fields from search result
                let tempMedia = result.toMedia(type: mediaType)
                unknownFields = tempMedia.unknownFields
                unknownFieldsOrder = tempMedia.unknownFieldsOrder
            } else if let original = originalMedia {
                // Preserve unknown fields from original
                unknownFields = original.unknownFields
                unknownFieldsOrder = original.unknownFieldsOrder
            }

            // Parse iTunes ID from search result or original
            let iTunesID: String? = {
                if isCreating, let result = initialSearchResult {
                    return String(result.id)
                }
                return originalMedia?.iTunesID
            }()

            let media = Media(
                id: sanitizedId,
                title: trimmedTitle,
                mediaType: mediaType,
                creator: creator.isEmpty ? nil : creator,
                releaseYear: Int(releaseYear),
                genre: genre.isEmpty ? nil : genre,
                artworkURL: artworkURL.isEmpty ? nil : artworkURL,
                iTunesID: iTunesID,
                iTunesURL: iTunesURL.isEmpty ? nil : iTunesURL,
                tags: tags,
                aliases: aliases,
                content: content,
                unknownFields: unknownFields,
                unknownFieldsOrder: unknownFieldsOrder
            )

            if isCreating {
                try await writer.write(media: media)
                createdMedia = media
            } else {
                try await writer.update(media: media)
            }

            // Reload media in VaultManager
            _ = try await vaultManager.loadMedia()

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Check if media has unsaved changes (edit mode only)
    var hasChanges: Bool {
        guard let original = originalMedia else { return false }

        return title != original.title ||
               creator != (original.creator ?? "") ||
               releaseYear != (original.releaseYear.map { String($0) } ?? "") ||
               genre != (original.genre ?? "") ||
               content != original.content ||
               tags != original.tags ||
               aliases != original.aliases
    }
}
