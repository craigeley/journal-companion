//
//  SearchCoordinator.swift
//  JournalCompanion
//
//  Central coordinator for app-wide search functionality
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SearchCoordinator: ObservableObject {
    // MARK: - Search State

    /// Whether the search drawer is currently visible
    @Published var isSearching: Bool = false

    /// The currently active tab (0 = Entries, 1 = People, 2 = Places)
    @Published var activeTab: Int = 0

    /// The current search text
    @Published var searchText: String = ""

    // MARK: - Filter State (Places only)

    /// Selected callout types for Places filtering (empty = all selected)
    @Published var selectedCalloutTypes: Set<String> = []

    /// Selected tags for Places filtering (empty = no tag filter)
    @Published var selectedTags: Set<String> = []

    // MARK: - Detail View Presentation

    /// Selected entry for detail presentation from search
    @Published var selectedEntry: Entry?

    /// Selected person for detail presentation from search
    @Published var selectedPerson: Person?

    /// Selected place for detail presentation from search
    @Published var selectedPlace: Place?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialize filters to "all selected" (no filtering)
        selectedCalloutTypes = Set(allCalloutTypes)

        // Debounce search text to avoid excessive filtering
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { _ in
                // Filtering happens in ViewModels via subscription
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Present the search drawer for the specified tab
    func presentSearch(for tab: Int) {
        activeTab = tab
        isSearching = true
        searchText = ""
    }

    /// Dismiss the search drawer and clear state
    func dismissSearch() {
        isSearching = false
        searchText = ""
        // Don't clear filters - preserve them for next search
    }

    /// Toggle a callout type filter (Places only)
    func toggleCalloutType(_ callout: String) {
        if selectedCalloutTypes.contains(callout) {
            selectedCalloutTypes.remove(callout)
        } else {
            selectedCalloutTypes.insert(callout)
        }
    }

    /// Toggle a tag filter (Places only)
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Reset all filters to default (all callouts, no tags)
    func resetFilters() {
        selectedCalloutTypes = Set(allCalloutTypes)
        selectedTags = []
    }

    /// Select all callout types
    func selectAllCalloutTypes() {
        selectedCalloutTypes = Set(allCalloutTypes)
    }

    /// Deselect all callout types
    func deselectAllCalloutTypes() {
        selectedCalloutTypes.removeAll()
    }

    /// Select all tags
    func selectAllTags() {
        selectedTags = Set(availableTags)
    }

    /// Deselect all tags
    func deselectAllTags() {
        selectedTags.removeAll()
    }

    /// Check if any filters are active (i.e., not showing all results)
    var hasActiveFilters: Bool {
        selectedCalloutTypes.count < allCalloutTypes.count || !selectedTags.isEmpty
    }

    /// Get available tags from places
    func updateAvailableTags(from places: [Place]) {
        let uniqueTags = Set(places.flatMap { $0.tags })
            .filter { !$0.isEmpty && $0 != "place" }
            .sorted()
        availableTags = uniqueTags
    }

    // MARK: - Public Properties

    /// All available callout types (matches PlaceIcon.allCalloutTypes)
    var allCalloutTypes: [String] {
        [
            "place", "cafe", "restaurant", "park", "school",
            "home", "shop", "grocery", "bar", "medical",
            "airport", "hotel", "library", "zoo", "museum",
            "workout", "concert", "movie", "entertainment", "service"
        ]
    }

    /// Available tags (extracted from places)
    @Published var availableTags: [String] = []
}
