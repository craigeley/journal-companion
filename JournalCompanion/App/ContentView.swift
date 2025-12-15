//
//  ContentView.swift
//  JournalCompanion
//
//  Main content view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @State private var showQuickEntry = false
    @State private var showEntryList = false
    @State private var vaultError: String?
    @State private var showDocumentPicker = false
    @State private var selectedVaultURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                if vaultManager.isVaultAccessible {
                    mainContent
                } else {
                    vaultSetup
                }

                // Floating action button
                if vaultManager.isVaultAccessible {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showQuickEntry = true
                            } label: {
                                Image(systemName: "square.and.pencil")
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
            .sheet(isPresented: $showEntryList) {
                let viewModel = EntryListViewModel(vaultManager: vaultManager, locationService: locationService)
                EntryListView(viewModel: viewModel)
            }
        }
    }

    private var mainContent: some View {
        List {
            Section {
                Button {
                    showEntryList = true
                } label: {
                    Label("Browse Entries", systemImage: "doc.text")
                }
            }

            Section("Places") {
                if vaultManager.isLoadingPlaces {
                    HStack {
                        ProgressView()
                        Text("Loading places...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("\(vaultManager.places.count) places loaded")
                        .foregroundStyle(.secondary)

                    if !vaultManager.places.isEmpty {
                        ForEach(vaultManager.places.prefix(5)) { place in
                            PlaceRow(place: place)
                        }

                        if vaultManager.places.count > 5 {
                            Text("+ \(vaultManager.places.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Button("Reload Places") {
                    Task {
                        _ = try? await vaultManager.loadPlaces()
                    }
                }
            }

            Section("Visit Tracking") {
                if !locationService.hasAlwaysAuthorization {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable automatic visit tracking to get notified when you visit places.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                locationService.requestAlwaysAuthorization()
                                let granted = await visitTracker.requestNotificationPermission()
                                if granted {
                                    print("Notification permission granted")
                                }
                            }
                        } label: {
                            Label("Enable Visit Tracking", systemImage: "location.circle")
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: visitTracker.isMonitoring ? "location.fill" : "location")
                            .foregroundStyle(visitTracker.isMonitoring ? .green : .secondary)

                        VStack(alignment: .leading) {
                            Text("Visit Tracking")
                                .font(.body)
                            Text(visitTracker.isMonitoring ? "Active" : "Inactive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: .init(
                            get: { visitTracker.isMonitoring },
                            set: { enabled in
                                if enabled {
                                    visitTracker.startMonitoring()
                                } else {
                                    visitTracker.stopMonitoring()
                                }
                            }
                        ))
                    }

                    if !visitTracker.recentVisits.isEmpty {
                        Text("\(visitTracker.recentVisits.count) recent visits tracked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section {
                Button("Reset Vault") {
                    vaultManager.clearVault()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Journal Companion")
        .task {
            if vaultManager.places.isEmpty {
                do {
                    _ = try await vaultManager.loadPlaces()
                } catch {
                    // Silently fail - user can manually reload
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
