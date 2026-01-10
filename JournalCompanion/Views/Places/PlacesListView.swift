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
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading places...")
                } else if viewModel.places.isEmpty {
                    ContentUnavailableView {
                        Label("No Places", systemImage: "mappin.slash")
                    } description: {
                        Text("Places will appear here after loading from your vault")
                    }
                } else if viewModel.filteredPlaces.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "line.3.horizontal.decrease.circle", description: Text("No places match your filter"))
                } else {
                    placesList
                }
            }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterMenu
                }
            }
            .task {
                await viewModel.loadPlacesIfNeeded()
            }
            .refreshable {
                await viewModel.reloadPlaces()
            }
        } detail: {
            if let place = selectedPlace {
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
    }

    private var placesList: some View {
        List(selection: $selectedPlace) {
            // View on Map navigation section
            Section {
                NavigationLink {
                    MapContentView(viewModel: MapViewModel(vaultManager: viewModel.vaultManager))
                        .environmentObject(locationService)
                        .environmentObject(templateManager)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        Text("View on Map")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            // Existing place sections
            ForEach(viewModel.placesByCallout, id: \.callout) { section in
                Section {
                    ForEach(section.places) { place in
                        PlaceRow(place: place)
                            .tag(place)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: PlaceIcon.systemName(for: section.callout))
                            .foregroundStyle(PlaceIcon.color(for: section.callout))
                        Text(section.callout.rawValue.capitalized)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filterMenu: some View {
        Menu {
            Section("Filter by Type") {
                ForEach(PlaceCallout.allCases, id: \.self) { callout in
                    Button {
                        viewModel.toggleCalloutType(callout)
                    } label: {
                        Label {
                            Text(callout.rawValue.capitalized)
                        } icon: {
                            Image(systemName: viewModel.isCalloutTypeSelected(callout) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }

            if !viewModel.selectedCalloutTypes.isEmpty {
                Divider()

                Button("Clear Filters") {
                    viewModel.clearCalloutTypeFilters()
                }
            }
        } label: {
            Image(systemName: viewModel.selectedCalloutTypes.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = PlacesListViewModel(vaultManager: vaultManager)
    return PlacesListView(viewModel: viewModel)
}
