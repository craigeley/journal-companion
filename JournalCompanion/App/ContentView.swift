//
//  ContentView.swift
//  JournalCompanion
//
//  Main content view
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @State private var showQuickEntry = false
    @State private var showPlaceCreation = false
    @State private var showLocationSearchForNewPlace = false
    @State private var pendingLocationName: String?
    @State private var pendingAddress: String?
    @State private var pendingCoordinates: CLLocationCoordinate2D?
    @State private var showSettings = false
    @State private var selectedTab = 0
    @State private var vaultError: String?
    @State private var showDocumentPicker = false
    @State private var selectedVaultURL: URL?

    var body: some View {
        ZStack {
            if vaultManager.isVaultAccessible {
                tabContent
            } else {
                vaultSetup
            }

            // Floating action button (context-aware)
            if vaultManager.isVaultAccessible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            // Context-aware action based on selected tab
                            if selectedTab == 0 {
                                // Entries tab - create entry
                                showQuickEntry = true
                            } else {
                                // Places tab (1) or Map tab (2) - start with location search
                                showLocationSearchForNewPlace = true
                            }
                        } label: {
                            // Context-aware icon
                            let iconName = selectedTab == 0 ? "square.and.pencil" : "mappin.circle"
                            Image(systemName: iconName)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickEntry) {
            let viewModel = QuickEntryViewModel(vaultManager: vaultManager, locationService: locationService)
            QuickEntryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showLocationSearchForNewPlace) {
            LocationSearchView(
                selectedLocationName: $pendingLocationName,
                selectedAddress: $pendingAddress,
                selectedCoordinates: $pendingCoordinates
            )
        }
        .onChange(of: showLocationSearchForNewPlace) { oldValue, newValue in
            // When location search dismisses
            if !newValue {
                // If location was selected, show creation form
                if pendingLocationName != nil {
                    showPlaceCreation = true
                }
                // If cancelled without selection, flow ends
            }
        }
        .sheet(isPresented: $showPlaceCreation, onDismiss: {
            // Clear pending location data
            pendingLocationName = nil
            pendingAddress = nil
            pendingCoordinates = nil
        }) {
            let viewModel = PlaceCreationViewModel(
                vaultManager: vaultManager,
                locationService: locationService,
                initialLocationName: pendingLocationName,
                initialAddress: pendingAddress,
                initialCoordinates: pendingCoordinates
            )
            PlaceCreationView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(visitTracker)
        }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            entriesTab
                .tabItem {
                    Label("Entries", systemImage: "doc.text")
                }
                .tag(0)

            placesTab
                .tabItem {
                    Label("Places", systemImage: "mappin.circle")
                }
                .tag(1)

            mapTab
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(2)
        }
    }

    private var entriesTab: some View {
        let viewModel = EntryListViewModel(
            vaultManager: vaultManager,
            locationService: locationService
        )
        return EntryListView(viewModel: viewModel)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
    }

    private var placesTab: some View {
        let viewModel = PlacesListViewModel(vaultManager: vaultManager)
        return PlacesListView(viewModel: viewModel)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
    }

    private var mapTab: some View {
        let viewModel = MapViewModel(vaultManager: vaultManager)
        return MapView(viewModel: viewModel)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
    }

    private var vaultSetup: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Select Your Vault")
                .font(.title2)
                .bold()

            Text("Use the Files app to navigate to your obsidian-journal vault folder")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showDocumentPicker = true
            } label: {
                Label("Select Vault Folder", systemImage: "folder.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedURL: $selectedVaultURL) {
                    showDocumentPicker = false
                }
            }
            .onChange(of: selectedVaultURL) { oldValue, newValue in
                guard let url = newValue else { return }
                Task {
                    do {
                        try await vaultManager.setVault(url: url)
                        _ = try await vaultManager.loadPlaces()
                    } catch {
                        print("Error setting vault: \(error)")
                        vaultError = error.localizedDescription
                    }
                }
            }
            .alert("Vault Error", isPresented: .constant(vaultError != nil)) {
                Button("OK") {
                    vaultError = nil
                }
            } message: {
                if let error = vaultError {
                    Text(error)
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(VaultManager())
}
