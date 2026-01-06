//
//  MediaListViewModel.swift
//  JournalCompanion
//
//  View model for Media list tab
//

import Foundation
import Combine
import SwiftUI

@MainActor
class MediaListViewModel: ObservableObject {
    @Published var filteredMedia: [Media] = []
    @Published var mediaByType: [(type: MediaType, items: [Media])] = []
    @Published var searchText: String = ""
    @Published var selectedTypes: Set<MediaType> = []
    @Published var isLoading = false

    let vaultManager: VaultManager
    private var cancellables = Set<AnyCancellable>()
    private var hasAttemptedLoad = false

    var media: [Media] {
        vaultManager.media
    }

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        // Debounce search text
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterMedia()
            }
            .store(in: &cancellables)

        // Re-filter when selected types change
        $selectedTypes
            .sink { [weak self] _ in
                self?.filterMedia()
            }
            .store(in: &cancellables)

        // Observe changes to vaultManager.media
        vaultManager.$media
            .sink { [weak self] _ in
                self?.filterMedia()
            }
            .store(in: &cancellables)

        // Update grouped media whenever filteredMedia changes
        $filteredMedia
            .sink { [weak self] media in
                self?.updateGroupedMedia(media)
            }
            .store(in: &cancellables)
    }

    func loadMediaIfNeeded() async {
        // Only load once on initial appearance
        guard !hasAttemptedLoad && !isLoading else {
            filterMedia()
            return
        }

        hasAttemptedLoad = true
        await reloadMedia()
    }

    func reloadMedia() async {
        isLoading = true
        do {
            _ = try await vaultManager.loadMedia()
            filterMedia()
        } catch {
            print("Failed to load media: \(error)")
        }
        isLoading = false
    }

    private func filterMedia() {
        var result = media

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.aliases.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (item.creator?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.genre?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by selected types (empty = show all)
        if !selectedTypes.isEmpty {
            result = result.filter { selectedTypes.contains($0.mediaType) }
        }

        filteredMedia = result
    }

    /// Update grouped media by type
    private func updateGroupedMedia(_ media: [Media]) {
        let grouped = Dictionary(grouping: media) { $0.mediaType }

        // Sort by type display name, only include types that have items
        mediaByType = MediaType.allCases
            .compactMap { type in
                guard let items = grouped[type], !items.isEmpty else { return nil }
                return (type: type, items: items.sorted { $0.title < $1.title })
            }
    }

    /// Toggle a media type filter
    func toggleType(_ type: MediaType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    /// Check if a type is selected
    func isTypeSelected(_ type: MediaType) -> Bool {
        selectedTypes.contains(type)
    }

    /// Clear filters (show all)
    func clearTypeFilters() {
        selectedTypes = []
    }

    /// Delete a media item
    func deleteMedia(_ media: Media) async throws {
        guard let vaultURL = vaultManager.vaultURL else {
            throw MediaError.invalidMedia
        }

        let writer = MediaWriter(vaultURL: vaultURL)
        try await writer.delete(media: media)
        _ = try await vaultManager.loadMedia()
    }
}
