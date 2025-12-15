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
    @State private var showPlaceDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading places...")
                } else if viewModel.placesWithCoordinates.isEmpty {
                    ContentUnavailableView {
                        Label("No Places on Map", systemImage: "map")
                    } description: {
                        Text("Places with coordinates will appear here")
                    }
                } else {
                    mapContent
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadPlacesIfNeeded()
                cameraPosition = viewModel.calculateInitialRegion()
            }
            .sheet(isPresented: $showPlaceDetail) {
                if let place = selectedPlace {
                    PlaceDetailView(place: place)
                }
            }
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.placesWithCoordinates) { place in
                if let coordinate = place.location {
                    Annotation(place.name, coordinate: coordinate) {
                        PlaceMapPin(
                            place: place,
                            isSelected: selectedPlace?.id == place.id
                        )
                        .onTapGesture {
                            selectedPlace = place
                            showPlaceDetail = true
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
