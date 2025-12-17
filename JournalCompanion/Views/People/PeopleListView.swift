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
            .sheet(item: $selectedPerson) { person in
                PersonDetailView(person: person)
                    .environmentObject(vaultManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(vaultManager)
            }
        }
    }

    private var peopleList: some View {
        List {
            ForEach(viewModel.filteredPeople) { person in
                PersonRow(person: person)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPerson = person
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
