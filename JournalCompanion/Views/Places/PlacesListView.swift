//
//  PlacesListView.swift
//  JournalCompanion
//
//  Places tab view showing all places with search and details
//

import SwiftUI

struct PlacesListView: View {
    @StateObject var viewModel: PlacesListViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @State private var selectedPlace: Place?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading places...")
                } else if viewModel.filteredPlaces.isEmpty && viewModel.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Places", systemImage: "mappin.slash")
                    } description: {
                        Text("Places will appear here after loading from your vault")
                    }
                } else if viewModel.filteredPlaces.isEmpty {
                    ContentUnavailableView.search
                } else {
                    placesList
                }
            }
            .navigationTitle("Places")
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
            .searchable(text: $viewModel.searchText, prompt: "Search places")
            .task {
                await viewModel.loadPlacesIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPlaces()
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
                    .environmentObject(viewModel.vaultManager)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel.vaultManager)
            }
        }
    }

    private var placesList: some View {
        List {
            ForEach(viewModel.placesByCallout(), id: \.callout) { section in
                Section {
                    ForEach(section.places) { place in
                        PlaceRow(place: place)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlace = place
                            }
                    }
                } header: {
                    Text(section.callout.capitalized)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = PlacesListViewModel(vaultManager: vaultManager)
    return PlacesListView(viewModel: viewModel)
}
