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

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading people...")
                } else if viewModel.filteredPeople.isEmpty && viewModel.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No People", systemImage: "person.3")
                    } description: {
                        Text("People will appear here after loading from your vault")
                    }
                } else if viewModel.filteredPeople.isEmpty {
                    ContentUnavailableView.search
                } else {
                    peopleList
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search people")
            .task {
                await viewModel.loadPeopleIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPeople()
            }
            .sheet(item: $selectedPerson) { person in
                PersonDetailView(person: person)
                    .environmentObject(vaultManager)
            }
        }
    }

    private var peopleList: some View {
        List {
            ForEach(viewModel.peopleByRelationshipType(), id: \.type) { section in
                Section {
                    ForEach(section.people) { person in
                        PersonRow(person: person)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPerson = person
                            }
                    }
                } header: {
                    Text(section.type.rawValue.capitalized)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = PeopleListViewModel(vaultManager: vaultManager)
    return PeopleListView(viewModel: viewModel)
        .environmentObject(vaultManager)
}
