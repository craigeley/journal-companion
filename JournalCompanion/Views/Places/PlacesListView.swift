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
    @State private var showMapView = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .task {
                await viewModel.loadPlacesIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPlaces()
            }
        } detail: {
            if showMapView {
                let mapViewModel = MapViewModel(vaultManager: viewModel.vaultManager)
                MapView(viewModel: mapViewModel)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            } else if let place = selectedPlace {
                PlaceDetailView(place: place)
                    .environmentObject(viewModel.vaultManager)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
                    .id(place.id)
            } else {
                ContentUnavailableView {
                    Label("Select a Place", systemImage: "mappin.circle")
                } description: {
                    Text("Choose a place from the list to view its details")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel.vaultManager)
        }
    }

    private var placesList: some View {
        List(selection: $selectedPlace) {
            // View on Map navigation section
            Section {
                Button {
                    selectedPlace = nil
                    showMapView = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        Text("View on Map")
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }

            // Existing place sections
            ForEach(viewModel.placesByCallout, id: \.callout) { section in
                Section {
                    ForEach(section.places) { place in
                        PlaceRow(place: place)
                            .tag(place)
                    }
                } header: {
                    Text(section.callout.capitalized)
                }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: selectedPlace) { _, newValue in
            // Clear map view when a place is selected
            if newValue != nil {
                showMapView = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = PlacesListViewModel(vaultManager: vaultManager)
    return PlacesListView(viewModel: viewModel)
}
