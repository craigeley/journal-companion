//
//  PeopleListView.swift
//  JournalCompanion
//
//  People tab view showing all people with search and details
//

import SwiftUI

struct PeopleListView: View {
    @StateObject var viewModel: PeopleListViewModel
    @EnvironmentObject var vaultManager: VaultManager
    @State private var selectedPerson: Person?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading people...")
                } else if viewModel.people.isEmpty {
                    ContentUnavailableView {
                        Label("No People", systemImage: "person.3")
                    } description: {
                        Text("People will appear here after loading from your vault")
                    }
                } else if viewModel.filteredPeople.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "line.3.horizontal.decrease.circle", description: Text("No people match your filter"))
                } else {
                    peopleList
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterMenu
                }
            }
            .task {
                await viewModel.loadPeopleIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPeople()
            }
        } detail: {
            if let person = selectedPerson {
                PersonDetailView(person: person)
                    .environmentObject(vaultManager)
                    .id(person.id)
            } else {
                ContentUnavailableView {
                    Label("Select a Person", systemImage: "person.circle")
                } description: {
                    Text("Choose a person from the list to view their details")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var peopleList: some View {
        List(selection: $selectedPerson) {
            ForEach(viewModel.peopleByRelationship, id: \.type) { section in
                Section {
                    ForEach(section.people) { person in
                        PersonRow(person: person)
                            .tag(person)
                    }
                } header: {
                    Text(section.type.rawValue.capitalized)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filterMenu: some View {
        Menu {
            Section("Filter by Relationship") {
                ForEach(RelationshipType.allCases, id: \.self) { type in
                    Button {
                        viewModel.toggleRelationshipType(type)
                    } label: {
                        Label {
                            Text(type.rawValue.capitalized)
                        } icon: {
                            Image(systemName: viewModel.isRelationshipTypeSelected(type) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }

            if !viewModel.selectedRelationshipTypes.isEmpty {
                Divider()

                Button("Clear Filters") {
                    viewModel.clearRelationshipTypeFilters()
                }
            }
        } label: {
            Image(systemName: viewModel.selectedRelationshipTypes.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = PeopleListViewModel(vaultManager: vaultManager)
    return PeopleListView(viewModel: viewModel)
        .environmentObject(vaultManager)
}
