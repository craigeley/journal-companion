//
//  ContentView.swift
//  JournalCompanion
//
//  Main content view
//

import SwiftUI
import CoreLocation
import MapKit
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @EnvironmentObject var searchCoordinator: SearchCoordinator
    @EnvironmentObject var visitNotificationCoordinator: VisitNotificationCoordinator
    @State private var showQuickEntry = false
    @State private var showAudioEntry = false
    @State private var showPhotoEntry = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
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
    @State private var showRecentVisits = false
    @State private var showDailyNoteCreation = false
    @State private var pendingVisitForEntry: PersistedVisit?
    @State private var selectedTab = 0
    @State private var vaultError: String?
    @State private var showDocumentPicker = false
    @State private var selectedVaultURL: URL?
    @State private var hasRequestedHealthKitAuth = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitAuth")
    @State private var showHealthKitAuth = false

    // Media entry states
    @State private var showMediaSearch = false
    @State private var showMediaEdit = false
    @State private var pendingMediaResult: iTunesSearchItem?
    @State private var pendingMediaType: MediaType?

    // Shared ViewModels for tabs and search
    @State private var entryViewModel: EntryListViewModel?
    @State private var peopleViewModel: PeopleListViewModel?
    @State private var placesViewModel: PlacesListViewModel?
    @State private var mediaViewModel: MediaListViewModel?

    var body: some View {
        mainContent
            .modifier(EntrySheetModifiers(
                showQuickEntry: $showQuickEntry,
                showAudioEntry: $showAudioEntry,
                showPhotoEntry: $showPhotoEntry,
                showPhotoPicker: $showPhotoPicker,
                selectedPhotoItem: $selectedPhotoItem,
                pendingVisitForEntry: $pendingVisitForEntry,
                vaultManager: vaultManager,
                locationService: locationService,
                templateManager: templateManager,
                visitNotificationCoordinator: visitNotificationCoordinator,
                quickEntrySheet: { quickEntrySheet }
            ))
            .modifier(PlaceAndPersonSheetModifiers(
                showPersonCreation: $showPersonCreation,
                showLocationSearchForNewPlace: $showLocationSearchForNewPlace,
                showPlaceCreation: $showPlaceCreation,
                pendingLocationName: $pendingLocationName,
                pendingAddress: $pendingAddress,
                pendingCoordinates: $pendingCoordinates,
                pendingURL: $pendingURL,
                pendingPOICategory: $pendingPOICategory,
                vaultManager: vaultManager,
                locationService: locationService,
                templateManager: templateManager
            ))
            .modifier(UtilitySheetModifiers(
                showSettings: $showSettings,
                showWorkoutSync: $showWorkoutSync,
                showRecentVisits: $showRecentVisits,
                showDailyNoteCreation: $showDailyNoteCreation,
                showHealthKitAuth: $showHealthKitAuth,
                hasRequestedHealthKitAuth: $hasRequestedHealthKitAuth,
                pendingVisitForEntry: $pendingVisitForEntry,
                showQuickEntry: $showQuickEntry,
                vaultManager: vaultManager,
                locationService: locationService,
                visitTracker: visitTracker,
                templateManager: templateManager,
                recentVisitsSheet: { recentVisitsSheet }
            ))
            .modifier(MediaSheetModifiers(
                showMediaSearch: $showMediaSearch,
                showMediaEdit: $showMediaEdit,
                pendingMediaResult: $pendingMediaResult,
                pendingMediaType: $pendingMediaType,
                vaultManager: vaultManager
            ))
            .modifier(SearchSheetModifiers(
                selectedEntry: $searchCoordinator.selectedEntry,
                selectedPerson: $searchCoordinator.selectedPerson,
                selectedPlace: $searchCoordinator.selectedPlace,
                vaultManager: vaultManager,
                locationService: locationService,
                templateManager: templateManager
            ))
            .modifier(LifecycleModifiers(
                selectedTab: $selectedTab,
                vaultManager: vaultManager,
                visitTracker: visitTracker,
                searchCoordinator: searchCoordinator,
                setupViewModels: setupViewModels,
                checkAndShowHealthKitAuth: checkAndShowHealthKitAuth
            ))
    }

    private var mainContent: some View {
        ZStack {
            contentSelector
            floatingActionButtons
        }
    }

    private var contentSelector: some View {
        Group {
            if vaultManager.isRestoringVault {
                vaultLoading
            } else if vaultManager.isVaultAccessible {
                tabContent
            } else {
                vaultSetup
            }
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var floatingActionButtons: some View {
        Group {
            if vaultManager.isVaultAccessible && selectedTab != 4 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        fabButton
                    }
                    .padding(.trailing, horizontalSizeClass == .regular ? 40 : 20)
                }
                .padding(.bottom, horizontalSizeClass == .regular ? 40 : 70)
            }
        }
    }

    @ViewBuilder
    private var fabButton: some View {
        if selectedTab == 0 {
            entriesFAB
        } else if selectedTab == 1 {
            peopleFAB
        } else if selectedTab == 2 {
            placesFAB
        } else if selectedTab == 3 {
            mediaFAB
        }
    }

    private var entriesFAB: some View {
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
                showPhotoPicker = true
            } label: {
                Label("Photo Entry", systemImage: "photo")
            }

            Button {
                showRecentVisits = true
            } label: {
                Label("Recent Visits", systemImage: "mappin.and.ellipse")
            }

            Button {
                showWorkoutSync = true
            } label: {
                Label("Sync Workouts", systemImage: "figure.run")
            }

            Button {
                showDailyNoteCreation = true
            } label: {
                Label("Daily Note", systemImage: "calendar.badge.plus")
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
    }

    private var peopleFAB: some View {
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
    }

    private var placesFAB: some View {
        Button {
            showLocationSearchForNewPlace = true
        } label: {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }

    private var mediaFAB: some View {
        Button {
            showMediaSearch = true
        } label: {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }

    private func setupViewModels() {
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
        if mediaViewModel == nil {
            mediaViewModel = MediaListViewModel(vaultManager: vaultManager)
        }
    }

    private func checkAndShowHealthKitAuth() {
        if !hasRequestedHealthKitAuth && vaultManager.isVaultAccessible {
            print("💡 Will show HealthKit auth in 0.5 seconds...")
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

    private func findPlaceByName(_ placeName: String?) -> Place? {
        guard let name = placeName, !name.isEmpty else {
            return nil
        }
        return vaultManager.places.first { $0.name == name }
    }

    private var recentVisitsSheet: some View {
        let viewModel = RecentVisitsViewModel(visitTracker: visitTracker)
        return RecentVisitsView(viewModel: viewModel) { selectedVisit in
            pendingVisitForEntry = selectedVisit
        }
    }

    private var quickEntrySheet: some View {
        // Prefer pendingVisitForEntry (from Recent Visits), otherwise use notification data
        let pendingVisit = pendingVisitForEntry
        let visitData = visitNotificationCoordinator.pendingVisitData

        let initialTimestamp = pendingVisit?.arrivalDate ?? visitData?.arrivalDate
        let initialCoordinates = pendingVisit?.coordinate ?? visitData?.coordinate
        let initialPlace = findPlaceByName(pendingVisit?.matchedPlaceName ?? visitData?.placeName)

        let viewModel = QuickEntryViewModel(
            vaultManager: vaultManager,
            locationService: locationService,
            initialTimestamp: initialTimestamp,
            initialCoordinates: initialCoordinates,
            initialPlace: initialPlace
        )

        return QuickEntryView(viewModel: viewModel)
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

            Tab(value: 3) {
                mediaTab
            } label: {
                Label("Media", systemImage: "play.rectangle.on.rectangle")
            }

            Tab(value: 4, role: .search) {
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
        .tabViewStyle(.sidebarAdaptable)
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

    private var mediaTab: some View {
        Group {
            if let viewModel = mediaViewModel {
                MediaListView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
            }
        }
    }

    private var vaultLoading: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading Vault...")
                .font(.title3)
                .foregroundStyle(.secondary)
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
                DocumentPicker(selectedURL: $selectedVaultURL, errorMessage: $vaultError) {
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

// MARK: - Sheet Modifiers

private struct EntrySheetModifiers<QuickEntry: View>: ViewModifier {
    @Binding var showQuickEntry: Bool
    @Binding var showAudioEntry: Bool
    @Binding var showPhotoEntry: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var pendingVisitForEntry: PersistedVisit?
    let vaultManager: VaultManager
    let locationService: LocationService
    let templateManager: TemplateManager
    let visitNotificationCoordinator: VisitNotificationCoordinator
    @ViewBuilder let quickEntrySheet: () -> QuickEntry

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showQuickEntry) {
                quickEntrySheet()
            }
            .onChange(of: showQuickEntry) { _, isShowing in
                if !isShowing {
                    pendingVisitForEntry = nil
                    visitNotificationCoordinator.clearPendingVisit()
                    Task {
                        do {
                            _ = try await vaultManager.loadEntries()
                        } catch {
                            print("❌ Failed to reload entries: \(error)")
                        }
                    }
                }
            }
            .onChange(of: visitNotificationCoordinator.shouldShowQuickEntry) { _, shouldShow in
                if shouldShow {
                    showQuickEntry = true
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
                    Task {
                        do {
                            _ = try await vaultManager.loadEntries()
                        } catch {
                            print("❌ Failed to reload entries: \(error)")
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                if newItem != nil {
                    showPhotoEntry = true
                }
            }
            .sheet(isPresented: $showPhotoEntry, onDismiss: {
                selectedPhotoItem = nil
            }) {
                let viewModel = PhotoEntryViewModel(
                    vaultManager: vaultManager,
                    locationService: locationService,
                    initialPhotoItem: selectedPhotoItem
                )
                PhotoEntryView(viewModel: viewModel)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            }
            .onChange(of: showPhotoEntry) { _, isShowing in
                if !isShowing {
                    Task {
                        do {
                            _ = try await vaultManager.loadEntries()
                        } catch {
                            print("❌ Failed to reload entries: \(error)")
                        }
                    }
                }
            }
    }
}

private struct PlaceAndPersonSheetModifiers: ViewModifier {
    @Binding var showPersonCreation: Bool
    @Binding var showLocationSearchForNewPlace: Bool
    @Binding var showPlaceCreation: Bool
    @Binding var pendingLocationName: String?
    @Binding var pendingAddress: String?
    @Binding var pendingCoordinates: CLLocationCoordinate2D?
    @Binding var pendingURL: String?
    @Binding var pendingPOICategory: MKPointOfInterestCategory?
    let vaultManager: VaultManager
    let locationService: LocationService
    let templateManager: TemplateManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPersonCreation) {
                let viewModel = PersonEditViewModel(
                    person: nil,
                    vaultManager: vaultManager,
                    templateManager: templateManager
                )
                PersonEditView(viewModel: viewModel)
                    .environmentObject(templateManager)
            }
            .onChange(of: showPersonCreation) { _, isShowing in
                if !isShowing {
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
            .onChange(of: showLocationSearchForNewPlace) { _, newValue in
                if !newValue {
                    if pendingLocationName != nil {
                        showPlaceCreation = true
                    }
                }
            }
            .sheet(isPresented: $showPlaceCreation, onDismiss: {
                pendingLocationName = nil
                pendingAddress = nil
                pendingCoordinates = nil
                pendingURL = nil
                pendingPOICategory = nil
            }) {
                let viewModel = PlaceEditViewModel(
                    place: nil,
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
                    Task {
                        do {
                            _ = try await vaultManager.loadPlaces()
                        } catch {
                            print("❌ Failed to reload places: \(error)")
                        }
                    }
                }
            }
    }
}

private struct UtilitySheetModifiers<RecentVisits: View>: ViewModifier {
    @Binding var showSettings: Bool
    @Binding var showWorkoutSync: Bool
    @Binding var showRecentVisits: Bool
    @Binding var showDailyNoteCreation: Bool
    @Binding var showHealthKitAuth: Bool
    @Binding var hasRequestedHealthKitAuth: Bool
    @Binding var pendingVisitForEntry: PersistedVisit?
    @Binding var showQuickEntry: Bool
    let vaultManager: VaultManager
    let locationService: LocationService
    let visitTracker: SignificantLocationTracker
    let templateManager: TemplateManager
    @ViewBuilder let recentVisitsSheet: () -> RecentVisits

    func body(content: Content) -> some View {
        content
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
                    Task {
                        do {
                            _ = try await vaultManager.loadEntries()
                        } catch {
                            print("❌ Failed to reload entries: \(error)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showRecentVisits) {
                recentVisitsSheet()
            }
            .onChange(of: showRecentVisits) { _, isShowing in
                if !isShowing && pendingVisitForEntry != nil {
                    showQuickEntry = true
                }
            }
            .sheet(isPresented: $showDailyNoteCreation) {
                DailyNoteCreationView(
                    viewModel: DailyNoteCreationViewModel(vaultManager: vaultManager)
                )
            }
            .sheet(isPresented: $showHealthKitAuth) {
                HealthKitAuthView()
                    .onDisappear {
                        UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitAuth")
                        hasRequestedHealthKitAuth = true
                    }
            }
    }
}

private struct MediaSheetModifiers: ViewModifier {
    @Binding var showMediaSearch: Bool
    @Binding var showMediaEdit: Bool
    @Binding var pendingMediaResult: iTunesSearchItem?
    @Binding var pendingMediaType: MediaType?
    let vaultManager: VaultManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showMediaSearch) {
                MediaSearchView { result, mediaType in
                    pendingMediaResult = result
                    pendingMediaType = mediaType
                }
            }
            .onChange(of: showMediaSearch) { _, newValue in
                if !newValue {
                    if pendingMediaResult != nil {
                        showMediaEdit = true
                    }
                }
            }
            .sheet(isPresented: $showMediaEdit, onDismiss: {
                pendingMediaResult = nil
                pendingMediaType = nil
            }) {
                if let result = pendingMediaResult, let type = pendingMediaType {
                    MediaEditView(viewModel: MediaEditViewModel(
                        vaultManager: vaultManager,
                        searchResult: result,
                        mediaType: type
                    ))
                }
            }
            .onChange(of: showMediaEdit) { _, isShowing in
                if !isShowing {
                    Task {
                        do {
                            _ = try await vaultManager.loadMedia()
                        } catch {
                            print("❌ Failed to reload media: \(error)")
                        }
                    }
                }
            }
    }
}

private struct SearchSheetModifiers: ViewModifier {
    @Binding var selectedEntry: Entry?
    @Binding var selectedPerson: Person?
    @Binding var selectedPlace: Place?
    let vaultManager: VaultManager
    let locationService: LocationService
    let templateManager: TemplateManager

    func body(content: Content) -> some View {
        content
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
                    .environmentObject(vaultManager)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            }
            .sheet(item: $selectedPerson) { person in
                let viewModel = PersonEditViewModel(
                    person: person,
                    vaultManager: vaultManager,
                    templateManager: templateManager
                )
                PersonEditView(viewModel: viewModel)
                    .environmentObject(templateManager)
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
                    .environmentObject(vaultManager)
                    .environmentObject(locationService)
                    .environmentObject(templateManager)
            }
    }
}

private struct LifecycleModifiers: ViewModifier {
    @Binding var selectedTab: Int
    let vaultManager: VaultManager
    let visitTracker: SignificantLocationTracker
    let searchCoordinator: SearchCoordinator
    let setupViewModels: () -> Void
    let checkAndShowHealthKitAuth: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                setupViewModels()
                checkAndShowHealthKitAuth()
            }
            .onChange(of: vaultManager.isVaultAccessible) { oldValue, newValue in
                print("📦 Vault accessibility changed: \(oldValue) -> \(newValue)")
                if newValue {
                    checkAndShowHealthKitAuth()
                }
            }
            .onChange(of: selectedTab) { _, _ in
                searchCoordinator.searchText = ""
            }
            .onChange(of: vaultManager.places) { _, newPlaces in
                visitTracker.places = newPlaces
            }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(VaultManager())
}
