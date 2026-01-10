//
//  MapView.swift
//  JournalCompanion
//
//  Map tab displaying all places with coordinates
//

import SwiftUI
import MapKit

/// Embeddable map content without NavigationStack - use this when embedding in NavigationSplitView
struct MapContentView: View {
    @ObservedObject var viewModel: MapViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPlace: Place?
    @State private var showFilterSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading places...")
            } else if viewModel.filteredPlaces.isEmpty {
                if viewModel.hasActiveFilters {
                    ContentUnavailableView {
                        Label("No Matching Places", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("No places match your current filters. Try adjusting your filter settings.")
                    } actions: {
                        Button("Reset Filters") {
                            viewModel.resetFilters()
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Places on Map", systemImage: "map")
                    } description: {
                        Text("Places with coordinates will appear here")
                    }
                }
            } else {
                mapContent
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterButton
            }
        }
        .task {
            await viewModel.loadPlacesIfNeeded()
        }
        .onChange(of: viewModel.filteredPlaces.map(\.id)) { _, _ in
            cameraPosition = viewModel.calculateInitialRegion()
        }
        .onAppear {
            if !viewModel.filteredPlaces.isEmpty {
                cameraPosition = viewModel.calculateInitialRegion()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            MapFilterView(viewModel: viewModel)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
                .environmentObject(viewModel.vaultManager)
                .environmentObject(locationService)
                .environmentObject(templateManager)
        }
    }

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")

                if viewModel.hasActiveFilters {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.filteredPlaces) { place in
                if let coordinate = place.location {
                    Annotation(place.name, coordinate: coordinate) {
                        PlaceMapPin(
                            place: place,
                            isSelected: selectedPlace?.id == place.id
                        )
                        .onTapGesture {
                            selectedPlace = place
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

/// Standalone MapView with its own NavigationStack - use for top-level presentation
struct MapView: View {
    @StateObject var viewModel: MapViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager

    var body: some View {
        NavigationStack {
            MapContentView(viewModel: viewModel)
                .environmentObject(locationService)
                .environmentObject(templateManager)
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = MapViewModel(vaultManager: vaultManager)
    return MapView(viewModel: viewModel)
}
