//
//  ContentView.swift
//  JournalCompanion
//
//  Main content view
//

import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @EnvironmentObject var searchCoordinator: SearchCoordinator
    @State private var showQuickEntry = false
    @State private var showAudioEntry = false
    @State private var showPersonCreation = false
    @State private var showPlaceCreation = false
    @State private var showLocationSearchForNewPlace = false
    @State private var pendingLocationName: String?
    @State private var pendingAddress: String?
    @State private var pendingCoordinates: CLLocationCoordinate2D?
    @State private var pendingURL: String?
    @State private var pendingPOICategory: MKPointOfInterestCategory?
    @State private var showSettings = false
    @State private var showWorkoutSync = false
    @State private var selectedTab = 0
    @State private var vaultError: String?
    @State private var showDocumentPicker = false
    @State private var selectedVaultURL: URL?
    @State private var hasRequestedHealthKitAuth = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitAuth")
    @State private var showHealthKitAuth = false

    // Shared ViewModels for tabs and search
    @State private var entryViewModel: EntryListViewModel?
    @State private var peopleViewModel: PeopleListViewModel?
    @State private var placesViewModel: PlacesListViewModel?

    var body: some View {
        ZStack {
            if vaultManager.isVaultAccessible {
                tabContent
            } else {
                vaultSetup
            }

            // Floating buttons (hide on search tab)
            if vaultManager.isVaultAccessible && selectedTab != 3 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        if selectedTab == 0 {
                            // Entries tab - menu FAB
                            Menu {
                                Button {
                                    showQuickEntry = true
                                } label: {
                                    Label("Text Entry", systemImage: "square.and.pencil")
                                }

                                Button {
                                    showAudioEntry = true
                                } label: {
                                    Label("Audio Entry", systemImage: "waveform")
                                }

                                Button {
                                    showWorkoutSync = true
                                } label: {
                                    Label("Sync Workouts", systemImage: "figure.run")
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .menuOrder(.fixed)
                        } else if selectedTab == 1 {
                            // People tab - single FAB
                            Button {
                                showPersonCreation = true
                            } label: {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        } else if selectedTab == 2 {
                            // Places tab - single FAB
                            Button {
                                showLocationSearchForNewPlace = true
                            } label: {
                                Image(systemName: "mappin.circle")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 70) // Extra padding to float above tab bar
            }

        }
        .sheet(isPresented: $showQuickEntry) {
            let viewModel = QuickEntryViewModel(vaultManager: vaultManager, locationService: locationService)
            QuickEntryView(viewModel: viewModel)
        }
        .onChange(of: showQuickEntry) { _, isShowing in
            if !isShowing {
                // Refresh entries when quick entry view closes
                Task {
                    do {
                        _ = try await vaultManager.loadEntries()
                    } catch {
                        print("❌ Failed to reload entries: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showAudioEntry) {
            let viewModel = AudioEntryViewModel(vaultManager: vaultManager, locationService: locationService)
            AudioEntryView(viewModel: viewModel)
                .environmentObject(locationService)
                .environmentObject(templateManager)
        }
        .onChange(of: showAudioEntry) { _, isShowing in
            if !isShowing {
                // Refresh entries when audio entry view closes
                Task {
                    do {
                        _ = try await vaultManager.loadEntries()
                    } catch {
                        print("❌ Failed to reload entries: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showPersonCreation) {
            let viewModel = PersonEditViewModel(
                person: nil,  // nil = creation mode
                vaultManager: vaultManager,
                templateManager: templateManager
            )
            PersonEditView(viewModel: viewModel)
                .environmentObject(templateManager)
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
                selectedCoordinates: $pendingCoordinates,
                selectedURL: $pendingURL,
                selectedPOICategory: $pendingPOICategory
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
            pendingURL = nil
            pendingPOICategory = nil
        }) {
            let viewModel = PlaceEditViewModel(
                place: nil,  // nil = creation mode
                vaultManager: vaultManager,
                locationService: locationService,
                templateManager: templateManager,
                initialLocationName: pendingLocationName,
                initialAddress: pendingAddress,
                initialCoordinates: pendingCoordinates,
                initialURL: pendingURL,
                initialPOICategory: pendingPOICategory
            )
            PlaceEditView(viewModel: viewModel)
                .environmentObject(templateManager)
        }
        .onChange(of: showPlaceCreation) { _, isShowing in
            if !isShowing {
                // Refresh places when creation view closes
                Task {
                    do {
                        _ = try await vaultManager.loadPlaces()
                    } catch {
                        print("❌ Failed to reload places: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(visitTracker)
                .environmentObject(templateManager)
        }
        .sheet(isPresented: $showWorkoutSync) {
            WorkoutSyncView(
                viewModel: WorkoutSyncViewModel(vaultManager: vaultManager)
            )
        }
        .onChange(of: showWorkoutSync) { _, isShowing in
            if !isShowing {
                // Refresh entries when workout sync closes
                Task {
                    do {
                        _ = try await vaultManager.loadEntries()
                    } catch {
                        print("❌ Failed to reload entries: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showHealthKitAuth) {
            HealthKitAuthView()
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitAuth")
                    hasRequestedHealthKitAuth = true
                }
        }
        .onAppear {
            // Initialize shared ViewModels once
            if entryViewModel == nil {
                entryViewModel = EntryListViewModel(
                    vaultManager: vaultManager,
                    locationService: locationService,
                    searchCoordinator: searchCoordinator
                )
            }
            if peopleViewModel == nil {
                peopleViewModel = PeopleListViewModel(
                    vaultManager: vaultManager,
                    searchCoordinator: searchCoordinator
                )
            }
            if placesViewModel == nil {
                placesViewModel = PlacesListViewModel(
                    vaultManager: vaultManager,
                    searchCoordinator: searchCoordinator
                )
            }

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
        .onChange(of: selectedTab) { _, _ in
            // Clear search when switching tabs
            searchCoordinator.searchText = ""
        }
        .sheet(item: $searchCoordinator.selectedEntry) { entry in
            // Entry detail from search
            EntryDetailView(entry: entry)
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(templateManager)
        }
        .sheet(item: $searchCoordinator.selectedPerson) { person in
            // Person detail from search
            let viewModel = PersonEditViewModel(
                person: person,
                vaultManager: vaultManager,
                templateManager: templateManager
            )
            PersonEditView(viewModel: viewModel)
                .environmentObject(templateManager)
        }
        .sheet(item: $searchCoordinator.selectedPlace) { place in
            // Place detail from search
            PlaceDetailView(place: place)
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(templateManager)
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
            Tab(value: 0) {
                entriesTab
            } label: {
                Label("Entries", systemImage: "doc.text")
            }

            Tab(value: 1) {
                peopleTab
            } label: {
                Label("People", systemImage: "person.2")
            }

            Tab(value: 2) {
                placesTab
            } label: {
                Label("Places", systemImage: "mappin.circle")
            }

            Tab(value: 3, role: .search) {
                NavigationStack {
                    if let entryVM = entryViewModel,
                       let peopleVM = peopleViewModel,
                       let placesVM = placesViewModel {
                        UniversalSearchView(
                            coordinator: searchCoordinator,
                            entryViewModel: entryVM,
                            peopleViewModel: peopleVM,
                            placesViewModel: placesVM
                        )
                        .environmentObject(vaultManager)
                        .navigationTitle("Search")
                        .searchable(text: $searchCoordinator.searchText)
                        .searchToolbarBehavior(.minimize)
                    } else {
                        ProgressView("Loading...")
                            .navigationTitle("Search")
                    }
                }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Update active tab in coordinator
            searchCoordinator.activeTab = newValue
        }
    }

    private var entriesTab: some View {
        Group {
            if let viewModel = entryViewModel {
                EntryListView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    private var peopleTab: some View {
        Group {
            if let viewModel = peopleViewModel {
                PeopleListView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
            }
        }
    }

    private var placesTab: some View {
        Group {
            if let viewModel = placesViewModel {
                PlacesListView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
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
