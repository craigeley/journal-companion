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
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(vaultManager)
        }
    }

    private var peopleList: some View {
        List(selection: $selectedPerson) {
            ForEach(viewModel.filteredPeople) { person in
                PersonRow(person: person)
                    .tag(person)
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
