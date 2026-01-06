//
//  MediaSearchViewModel.swift
//  JournalCompanion
//
//  ViewModel for searching iTunes for media
//

import Foundation
import Combine

@MainActor
class MediaSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedMediaType: MediaType = .movie
    @Published var searchResults: [iTunesSearchItem] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var hasSearched = false

    private let searchService = iTunesSearchService()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupDebounce()
    }

    private func setupDebounce() {
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)

        // Re-search when media type changes
        $selectedMediaType
            .dropFirst()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }

    /// Perform search with current parameters
    func performSearch() {
        // Cancel any existing search
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }

        isSearching = true
        errorMessage = nil

        let mediaType = selectedMediaType

        searchTask = Task {
            do {
                let results = try await searchService.search(
                    term: query,
                    mediaType: mediaType,
                    limit: 30
                )

                if !Task.isCancelled {
                    searchResults = results
                    hasSearched = true
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    searchResults = []
                    hasSearched = true
                }
            }

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    /// Clear search state
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        errorMessage = nil
        hasSearched = false
        isSearching = false
    }

    /// Convert selected result to Media model
    func createMedia(from result: iTunesSearchItem) -> Media {
        result.toMedia(type: selectedMediaType)
    }
}
