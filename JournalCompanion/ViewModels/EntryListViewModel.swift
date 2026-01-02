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
    @Published var filteredEntries: [Entry] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Filter State
    @Published var selectedDate: Date?
    @Published var selectedEntryTypes: Set<Entry.EntryType> = Set(Entry.EntryType.allCases)

    let allEntryTypes: [Entry.EntryType] = Entry.EntryType.allCases

    let vaultManager: VaultManager
    let locationService: LocationService
    let searchCoordinator: SearchCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var entries: [Entry] {
        vaultManager.entries
    }

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

        // Observe changes to vaultManager.entries
        vaultManager.$entries
            .sink { [weak self] entries in
                self?.filterEntries(entries: entries, searchText: self?.searchText ?? "")
            }
            .store(in: &cancellables)

        // React to filter changes (debounced)
        Publishers.CombineLatest($selectedDate, $selectedEntryTypes)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.filterEntries(searchText: self?.searchText ?? "")
            }
            .store(in: &cancellables)
    }

    /// Load entries from vault
    func loadEntries() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await vaultManager.loadEntries(limit: 100)
            filterEntries(searchText: searchText)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load entries: \(error)")
        }

        isLoading = false
    }

    /// Filter entries based on search text, date, and entry types
    private func filterEntries(entries: [Entry]? = nil, searchText: String) {
        let entriesToFilter = entries ?? self.entries

        // Apply search filter
        var results = entriesToFilter
        if !searchText.isEmpty {
            results = results.filter { entry in
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

        // Apply date filter
        if let selectedDate = selectedDate {
            let calendar = Calendar.current
            let targetDay = calendar.startOfDay(for: selectedDate)
            results = results.filter { entry in
                calendar.startOfDay(for: entry.dateCreated) == targetDay
            }
        }

        // Apply entry type filter
        if selectedEntryTypes.count < allEntryTypes.count {
            results = results.filter { entry in
                selectedEntryTypes.contains(entry.entryType)
            }
        }

        filteredEntries = results
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
        return places.first { $0.name == placeName }?.callout.rawValue
    }

    /// Delete an entry
    func deleteEntry(_ entry: Entry, deleteAttachments: Bool = false) async throws {
        guard let vaultURL = vaultManager.vaultURL else {
            throw NSError(domain: "EntryListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vault configured"])
        }

        let writer = EntryWriter(vaultURL: vaultURL)
        try await writer.delete(entry: entry, deleteAttachments: deleteAttachments)

        // Reload entries from vault to update the list
        _ = try await vaultManager.loadEntries(limit: 100)

        print("✓ Deleted entry and reloaded list")
    }

    // MARK: - Filter Controls

    /// Toggle entry type selection
    func toggleEntryType(_ type: Entry.EntryType) {
        if selectedEntryTypes.contains(type) {
            selectedEntryTypes.remove(type)
        } else {
            selectedEntryTypes.insert(type)
        }
    }

    /// Clear date filter
    func clearDateFilter() {
        selectedDate = nil
    }

    /// Clear entry type filters
    func clearEntryTypeFilters() {
        selectedEntryTypes = Set(allEntryTypes)
    }

    /// Reset all filters to default (show everything)
    func resetAllFilters() {
        selectedDate = nil
        selectedEntryTypes = Set(allEntryTypes)
    }

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        selectedDate != nil || selectedEntryTypes.count < allEntryTypes.count
    }

    /// Date range for calendar picker (earliest entry through today)
    var calendarDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let earliestEntry = entries.map({ $0.dateCreated }).min() else {
            // No entries yet - allow current month
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            return startOfMonth...today
        }

        let earliestDay = calendar.startOfDay(for: earliestEntry)
        return earliestDay...today
    }

    /// Get active filter descriptions for chips
    var activeFilterChips: [FilterChip] {
        var chips: [FilterChip] = []

        // Date filter chip
        if let date = selectedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            chips.append(FilterChip(
                id: "date",
                label: formatter.string(from: date),
                systemImage: "calendar",
                onRemove: { [weak self] in self?.clearDateFilter() }
            ))
        }

        // Entry type chips (only if some types are deselected)
        if selectedEntryTypes.count < allEntryTypes.count && !selectedEntryTypes.isEmpty {
            for type in selectedEntryTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                chips.append(FilterChip(
                    id: "type-\(type.rawValue)",
                    label: type.rawValue,
                    systemImage: type.systemImage,
                    onRemove: { [weak self] in self?.toggleEntryType(type) }
                ))
            }
        }

        return chips
    }
}

// MARK: - Filter Chip Model
struct FilterChip: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let onRemove: () -> Void
}
