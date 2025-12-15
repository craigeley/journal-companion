//
//  PlacesListView.swift
//  JournalCompanion
//
//  Places tab view showing all places with search and details
//

import SwiftUI

struct PlacesListView: View {
    @StateObject var viewModel: PlacesListViewModel
    @State private var selectedPlace: Place?
    @State private var showPlaceDetail = false

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
            .searchable(text: $viewModel.searchText, prompt: "Search places")
            .task {
                await viewModel.loadPlacesIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPlaces()
            }
            .sheet(isPresented: $showPlaceDetail) {
                if let place = selectedPlace {
                    PlaceDetailView(place: place)
                }
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
                                showPlaceDetail = true
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
