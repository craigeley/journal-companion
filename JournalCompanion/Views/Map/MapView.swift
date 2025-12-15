//
//  MapView.swift
//  JournalCompanion
//
//  Map tab displaying all places with coordinates
//

import SwiftUI
import MapKit

struct MapView: View {
    @StateObject var viewModel: MapViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPlace: Place?
    @State private var showFilterSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading places...")
                } else if viewModel.filteredPlaces.isEmpty {
                    if viewModel.hasActiveFilters {
                        // Empty due to filters
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
                        // Empty overall
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
                    Button {
                        showFilterSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")

                            // Badge indicator when filters are active
                            if viewModel.hasActiveFilters {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
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
                PlaceEditView(viewModel: PlaceEditViewModel(
                    place: place,
                    vaultManager: viewModel.vaultManager
                ))
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

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let viewModel = MapViewModel(vaultManager: vaultManager)
    return MapView(viewModel: viewModel)
}
