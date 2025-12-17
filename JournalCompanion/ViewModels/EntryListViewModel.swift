//
//  EntryListViewModel.swift
//  JournalCompanion
//
//  View model for entry list and search
//

import Foundation
import Combine
import CoreLocation

@MainActor
class EntryListViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var filteredEntries: [Entry] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let vaultManager: VaultManager
    let locationService: LocationService
    let searchCoordinator: SearchCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var places: [Place] {
        vaultManager.places
    }

    var people: [Person] {
        vaultManager.people
    }

    init(vaultManager: VaultManager, locationService: LocationService, searchCoordinator: SearchCoordinator? = nil) {
        self.vaultManager = vaultManager
        self.locationService = locationService
        self.searchCoordinator = searchCoordinator

        // Subscribe to SearchCoordinator (if provided)
        if let searchCoordinator = searchCoordinator {
            searchCoordinator.$searchText
                .sink { [weak self] text in
                    // Filter if Entries tab (0) or Search tab (3) is active
                    if searchCoordinator.activeTab == 0 || searchCoordinator.activeTab == 3 {
                        self?.filterEntries(searchText: text)
                    }
                }
                .store(in: &cancellables)
        }

        // Keep existing $searchText subscription for backward compatibility
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterEntries(searchText: searchText)
            }
            .store(in: &cancellables)
    }

    /// Load entries from vault
    func loadEntries() async {
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            let loadedEntries = try await reader.loadEntries(limit: 100) // Load recent 100 entries

            entries = loadedEntries
            filteredEntries = loadedEntries
            print("✓ Loaded \(entries.count) entries")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load entries: \(error)")
        }

        isLoading = false
    }

    /// Filter entries based on search text
    private func filterEntries(searchText: String) {
        if searchText.isEmpty {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter { entry in
                // Search in content
                if entry.content.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search in place name
                if let place = entry.place, place.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search in tags
                if entry.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }

                return false
            }
        }
    }

    /// Group entries by date
    func entriesByDate() -> [(date: Date, entries: [Entry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.startOfDay(for: entry.dateCreated)
        }

        return grouped.map { (date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Look up place callout by place name
    func callout(for placeName: String?) -> String? {
        guard let placeName = placeName else { return nil }
        return places.first { $0.name == placeName }?.callout
    }

    /// Delete an entry
    func deleteEntry(_ entry: Entry) async throws {
        guard let vaultURL = vaultManager.vaultURL else {
            throw NSError(domain: "EntryListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vault configured"])
        }

        let writer = EntryWriter(vaultURL: vaultURL)
        try await writer.delete(entry: entry)

        // Remove from local arrays
        entries.removeAll { $0.id == entry.id }
        filteredEntries.removeAll { $0.id == entry.id }

        print("✓ Deleted entry from list")
    }
}
