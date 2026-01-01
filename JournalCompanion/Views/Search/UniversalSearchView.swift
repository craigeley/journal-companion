//
//  UniversalSearchView.swift
//  JournalCompanion
//
//  Context-aware bottom search drawer with Liquid Glass styling
//

import SwiftUI

struct UniversalSearchView: View {
    @ObservedObject var coordinator: SearchCoordinator
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    @State private var showFilterSheet = false

    // ViewModels for search results
    let entryViewModel: EntryListViewModel?
    let peopleViewModel: PeopleListViewModel?
    let placesViewModel: PlacesListViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips (only for Places tab)
            if coordinator.activeTab == 2 {
                filterChipsView
            }

            // Results
            resultsScrollView
        }
        .sheet(isPresented: $showFilterSheet) {
            // Filter sheet for Places
            if let placesViewModel = placesViewModel {
                UniversalFilterView(coordinator: coordinator, placesViewModel: placesViewModel)
            }
        }
    }

    // MARK: - Filter Chips (Places only)

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter button
                Button {
                    showFilterSheet = true
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }

                // Active filter count badge
                if coordinator.hasActiveFilters {
                    Text("\(activeFilterCount) active")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var activeFilterCount: Int {
        let calloutFilters = PlaceCallout.allCases.count - coordinator.selectedCalloutTypes.count
        let tagFilters = coordinator.selectedTags.count
        return calloutFilters + (tagFilters > 0 ? tagFilters : 0)
    }

    // MARK: - Results

    private var resultsScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if coordinator.searchText.isEmpty {
                    emptyStateView
                } else {
                    resultsView
                }
            }
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        switch coordinator.activeTab {
        case 0:
            // Entries tab - show only entries
            if let entryViewModel = entryViewModel {
                entryResultsView(entryViewModel)
            }
        case 1:
            // People tab - show only people
            if let peopleViewModel = peopleViewModel {
                peopleResultsView(peopleViewModel)
            }
        case 2:
            // Places tab - show only places
            if let placesViewModel = placesViewModel {
                placesResultsView(placesViewModel)
            }
        case 3:
            // Search tab - show ALL results
            VStack(spacing: 0) {
                if let entryViewModel = entryViewModel, !entryViewModel.filteredEntries.isEmpty {
                    sectionHeader("Entries")
                    entryResultsView(entryViewModel)
                }

                if let peopleViewModel = peopleViewModel, !peopleViewModel.filteredPeople.isEmpty {
                    sectionHeader("People")
                    peopleResultsView(peopleViewModel)
                }

                if let placesViewModel = placesViewModel, !placesViewModel.filteredPlaces.isEmpty {
                    sectionHeader("Places")
                    placesResultsView(placesViewModel)
                }

                // Show message if no results at all
                if let entryVM = entryViewModel,
                   let peopleVM = peopleViewModel,
                   let placesVM = placesViewModel,
                   entryVM.filteredEntries.isEmpty && peopleVM.filteredPeople.isEmpty && placesVM.filteredPlaces.isEmpty {
                    noResultsView(for: "any items")
                }
            }
        default:
            EmptyView()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Entry Results

    private func entryResultsView(_ viewModel: EntryListViewModel) -> some View {
        Group {
            if viewModel.filteredEntries.isEmpty {
                noResultsView(for: "entries")
            } else {
                ForEach(viewModel.filteredEntries.prefix(20)) { entry in
                    Button {
                        coordinator.selectedEntry = entry
                        coordinator.dismissSearch()
                    } label: {
                        EntrySearchRow(
                            entry: entry,
                            placeCallout: viewModel.callout(for: entry.place),
                            searchText: coordinator.searchText
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - People Results

    private func peopleResultsView(_ viewModel: PeopleListViewModel) -> some View {
        Group {
            if viewModel.filteredPeople.isEmpty {
                noResultsView(for: "people")
            } else {
                ForEach(viewModel.filteredPeople.prefix(20)) { person in
                    Button {
                        coordinator.selectedPerson = person
                        coordinator.dismissSearch()
                    } label: {
                        PersonRow(person: person)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Places Results

    private func placesResultsView(_ viewModel: PlacesListViewModel) -> some View {
        Group {
            if viewModel.filteredPlaces.isEmpty {
                noResultsForPlaces
            } else {
                ForEach(viewModel.filteredPlaces.prefix(20)) { place in
                    Button {
                        coordinator.selectedPlace = place
                        coordinator.dismissSearch()
                    } label: {
                        PlaceRow(place: place)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Search \(tabName)", systemImage: "magnifyingglass")
        } description: {
            Text("Start typing to find \(tabName.lowercased())")
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    private func noResultsView(for type: String) -> some View {
        ContentUnavailableView {
            Label("No \(type.capitalized) Found", systemImage: "magnifyingglass")
        } description: {
            Text("No \(type) match '\(coordinator.searchText)'")
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    private var noResultsForPlaces: some View {
        ContentUnavailableView {
            Label("No Places Found", systemImage: "magnifyingglass")
        } description: {
            if coordinator.hasActiveFilters {
                Text("No places match your search and filters. Try adjusting your filters.")
            } else {
                Text("No places match '\(coordinator.searchText)'")
            }
        } actions: {
            if coordinator.hasActiveFilters {
                Button("Reset Filters") {
                    coordinator.resetFilters()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    private var tabName: String {
        switch coordinator.activeTab {
        case 0: return "Entries"
        case 1: return "People"
        case 2: return "Places"
        default: return "Items"
        }
    }
}

// MARK: - Entry Search Row

private struct EntrySearchRow: View {
    let entry: Entry
    let placeCallout: String?
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with time and place
            HStack {
                Text(entry.dateCreated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let place = entry.place {
                    Image(systemName: PlaceIcon.systemName(for: placeCallout ?? ""))
                        .foregroundStyle(PlaceIcon.color(for: placeCallout ?? ""))
                        .font(.caption)
                        .imageScale(.small)
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.dateCreated, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Preview of content (first 100 characters)
            Text(entry.content.prefix(100))
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Tags
            if !entry.tags.isEmpty {
                Text(entry.tags.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
