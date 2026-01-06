//
//  PeopleListViewModel.swift
//  JournalCompanion
//
//  View model for People list tab
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PeopleListViewModel: ObservableObject {
    @Published var filteredPeople: [Person] = []
    @Published var peopleByRelationship: [(type: RelationshipType, people: [Person])] = []
    @Published var searchText: String = ""
    @Published var selectedRelationshipTypes: Set<RelationshipType> = []
    @Published var isLoading = false

    let vaultManager: VaultManager
    let searchCoordinator: SearchCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var people: [Person] {
        vaultManager.people
    }

    init(vaultManager: VaultManager, searchCoordinator: SearchCoordinator? = nil) {
        self.vaultManager = vaultManager
        self.searchCoordinator = searchCoordinator

        // Subscribe to SearchCoordinator (if provided)
        if let searchCoordinator = searchCoordinator {
            searchCoordinator.$searchText
                .sink { [weak self] text in
                    // Filter if People tab (1) or Search tab (4) is active
                    if searchCoordinator.activeTab == 1 || searchCoordinator.activeTab == 4 {
                        self?.searchText = text
                    }
                }
                .store(in: &cancellables)
        }

        // Observe changes to vaultManager.people
        vaultManager.$people
            .sink { [weak self] _ in
                self?.filterPeople()
            }
            .store(in: &cancellables)

        // React to filter changes (debounced) - combines search and relationship type filters
        Publishers.CombineLatest($searchText, $selectedRelationshipTypes)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.filterPeople()
            }
            .store(in: &cancellables)

        // Update grouped people whenever filteredPeople changes
        $filteredPeople
            .sink { [weak self] people in
                self?.updateGroupedPeople(people)
            }
            .store(in: &cancellables)
    }

    func loadPeopleIfNeeded() async {
        if people.isEmpty {
            await reloadPeople()
        } else {
            filterPeople()
        }
    }

    func reloadPeople() async {
        isLoading = true
        do {
            _ = try await vaultManager.loadPeople()
            filterPeople()
        } catch {
            print("Failed to load people: \(error)")
        }
        isLoading = false
    }

    private func filterPeople() {
        var result = people

        // Filter by selected relationship types (empty = show all)
        if !selectedRelationshipTypes.isEmpty {
            result = result.filter { selectedRelationshipTypes.contains($0.relationshipType) }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.relationshipType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                person.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (person.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (person.pronouns?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        filteredPeople = result
    }

    /// Update grouped people whenever filteredPeople changes
    private func updateGroupedPeople(_ people: [Person]) {
        let grouped = Dictionary(grouping: people) { $0.relationshipType }

        // Sort by relationship type, only include types that have people
        peopleByRelationship = RelationshipType.allCases
            .compactMap { type in
                guard let items = grouped[type], !items.isEmpty else { return nil }
                return (type: type, people: items.sorted { $0.name < $1.name })
            }
    }

    /// Toggle a relationship type filter
    func toggleRelationshipType(_ type: RelationshipType) {
        if selectedRelationshipTypes.contains(type) {
            selectedRelationshipTypes.remove(type)
        } else {
            selectedRelationshipTypes.insert(type)
        }
    }

    /// Check if a relationship type is selected
    func isRelationshipTypeSelected(_ type: RelationshipType) -> Bool {
        selectedRelationshipTypes.contains(type)
    }

    /// Clear filters (show all)
    func clearRelationshipTypeFilters() {
        selectedRelationshipTypes = []
    }
}
