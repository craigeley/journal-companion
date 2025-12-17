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
    @Published var searchText: String = ""
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
                    // Filter if People tab (1) or Search tab (3) is active
                    if searchCoordinator.activeTab == 1 || searchCoordinator.activeTab == 3 {
                        self?.filterPeople(searchText: text)
                    }
                }
                .store(in: &cancellables)
        }

        // Keep existing $searchText subscription for backward compatibility
        $searchText
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterPeople(searchText: searchText)
            }
            .store(in: &cancellables)

        // Observe changes to vaultManager.people
        vaultManager.$people
            .sink { [weak self] _ in
                self?.filterPeople(searchText: self?.searchText ?? "")
            }
            .store(in: &cancellables)
    }

    func loadPeopleIfNeeded() async {
        if people.isEmpty {
            await reloadPeople()
        } else {
            filterPeople(searchText: searchText)
        }
    }

    func reloadPeople() async {
        isLoading = true
        do {
            _ = try await vaultManager.loadPeople()
            filterPeople(searchText: searchText)
        } catch {
            print("Failed to load people: \(error)")
        }
        isLoading = false
    }

    private func filterPeople(searchText: String) {
        if searchText.isEmpty {
            filteredPeople = people
        } else {
            filteredPeople = people.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.relationshipType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                person.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (person.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (person.pronouns?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    /// Group people by relationship type
    func peopleByRelationshipType() -> [(type: RelationshipType, people: [Person])] {
        let grouped = Dictionary(grouping: filteredPeople) { person in
            person.relationshipType
        }

        return grouped.map { (type: $0.key, people: $0.value) }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }
}
