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
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @State private var showQuickEntry = false
    @State private var showPersonCreation = false
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
    @State private var hasRequestedHealthKitAuth = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitAuth")
    @State private var showHealthKitAuth = false

    // Debug: Manual trigger for HealthKit auth
    private func showHealthKitAuthManually() {
        print("🔧 DEBUG: Manually triggering HealthKit auth")
        showHealthKitAuth = true
    }

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
                            } else if selectedTab == 1 {
                                // People tab - create person
                                showPersonCreation = true
                            } else {
                                // Places tab (2) or Map tab (3) - start with location search
                                showLocationSearchForNewPlace = true
                            }
                        } label: {
                            // Context-aware icon based on selected tab
                            Image(systemName: selectedTab == 0 ? "square.and.pencil" :
                                               selectedTab == 1 ? "person.crop.circle.badge.plus" :
                                               "mappin.circle")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 70) // Extra padding to float above tab bar
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickEntry) {
            let viewModel = QuickEntryViewModel(vaultManager: vaultManager, locationService: locationService)
            QuickEntryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPersonCreation) {
            let viewModel = PersonCreationViewModel(vaultManager: vaultManager, templateManager: templateManager)
            PersonCreationView(viewModel: viewModel)
        }
        .onChange(of: showPersonCreation) { _, isShowing in
            if !isShowing {
                // Refresh people when creation view closes
                Task {
                    do {
                        _ = try await vaultManager.loadPeople()
                    } catch {
                        print("❌ Failed to reload people: \(error)")
                    }
                }
            }
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
                templateManager: templateManager,
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
                .environmentObject(templateManager)
        }
        .sheet(isPresented: $showHealthKitAuth) {
            HealthKitAuthView()
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitAuth")
                    hasRequestedHealthKitAuth = true
                }
        }
        .onAppear {
            // Show HealthKit authorization on first launch
            print("🏁 ContentView appeared. hasRequestedHealthKitAuth: \(hasRequestedHealthKitAuth), vaultAccessible: \(vaultManager.isVaultAccessible)")
            checkAndShowHealthKitAuth()
        }
        .onChange(of: vaultManager.isVaultAccessible) { oldValue, newValue in
            // When vault becomes accessible, show HealthKit auth if not requested yet
            print("📦 Vault accessibility changed: \(oldValue) -> \(newValue)")
            if newValue {
                checkAndShowHealthKitAuth()
            }
        }
    }

    private func checkAndShowHealthKitAuth() {
        if !hasRequestedHealthKitAuth && vaultManager.isVaultAccessible {
            print("💡 Will show HealthKit auth in 0.5 seconds...")
            // Delay slightly to allow app to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("📱 Showing HealthKit authorization view")
                showHealthKitAuth = true
            }
        } else if hasRequestedHealthKitAuth {
            print("⏭️ Already requested HealthKit auth, skipping")
        } else {
            print("⏭️ Vault not accessible yet, waiting...")
        }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            entriesTab
                .tabItem {
                    Label("Entries", systemImage: "doc.text")
                }
                .tag(0)

            peopleTab
                .tabItem {
                    Label("People", systemImage: "person.2")
                }
                .tag(1)

            placesTab
                .tabItem {
                    Label("Places", systemImage: "mappin.circle")
                }
                .tag(2)

            mapTab
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(3)
        }
    }

    private var entriesTab: some View {
        let viewModel = EntryListViewModel(
            vaultManager: vaultManager,
            locationService: locationService
        )
        return EntryListView(viewModel: viewModel)
    }

    private var peopleTab: some View {
        let viewModel = PeopleListViewModel(vaultManager: vaultManager)
        return PeopleListView(viewModel: viewModel)
    }

    private var placesTab: some View {
        let viewModel = PlacesListViewModel(vaultManager: vaultManager)
        return PlacesListView(viewModel: viewModel)
    }

    private var mapTab: some View {
        let viewModel = MapViewModel(vaultManager: vaultManager)
        return MapView(viewModel: viewModel)
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
