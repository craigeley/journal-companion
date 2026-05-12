//
//  SettingsView.swift
//  JournalCompanion
//
//  Dedicated settings screen for app configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var visitTracker: SignificantLocationTracker
    @EnvironmentObject var templateManager: TemplateManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("audioFormat") private var audioFormat: AudioFormat = .aac

    @State private var isMigrating = false
    @State private var migrationReportSummary: String?
    @State private var showingMigrationConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Places Settings Section
                Section("Places") {
                    HStack {
                        Text("Loaded Places")
                        Spacer()
                        Text("\(vaultManager.places.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button("Reload Places") {
                        Task {
                            _ = try? await vaultManager.loadPlaces()
                        }
                    }
                }

                // Visit Tracking Section
                Section("Visit Tracking") {
                    if !locationService.hasAlwaysAuthorization {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enable visit tracking to record locations you spend time at. View recent visits from the Entries tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                locationService.requestAlwaysAuthorization()
                            } label: {
                                Label("Enable Visit Tracking", systemImage: "location.circle")
                            }
                        }
                    } else {
                        Toggle(isOn: .init(
                            get: { visitTracker.isMonitoring },
                            set: { enabled in
                                if enabled {
                                    visitTracker.startMonitoring()
                                } else {
                                    visitTracker.stopMonitoring()
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: visitTracker.isMonitoring ? "location.fill" : "location")
                                    .foregroundStyle(visitTracker.isMonitoring ? .green : .secondary)

                                VStack(alignment: .leading) {
                                    Text("Visit Tracking")
                                    Text(visitTracker.isMonitoring ? "Active" : "Inactive")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !visitTracker.recentVisits.isEmpty {
                            Text("\(visitTracker.recentVisits.count) recent visits tracked")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Audio Section
                Section("Audio") {
                    Picker("Recording Quality", selection: $audioFormat) {
                        ForEach(AudioFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Audio format applies to new recordings. Existing recordings are not affected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Templates Section
                Section("Templates") {
                    NavigationLink {
                        PersonTemplateSettingsView()
                            .environmentObject(templateManager)
                    } label: {
                        Label("Person Template", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        PlaceTemplateSettingsView()
                            .environmentObject(templateManager)
                    } label: {
                        Label("Place Template", systemImage: "map.circle")
                    }
                }

                // Development Section
                Section("Development") {
                    NavigationLink {
                        AppIconGeneratorView()
                    } label: {
                        Label("App Icon Generator", systemImage: "app.badge")
                    }
                }

                // Vault Settings Section
                Section("Vault") {
                    if let vaultURL = vaultManager.vaultURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vaultURL.path)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button("Reset Vault", role: .destructive) {
                        vaultManager.clearVault()
                    }
                }

                // Vault Structure Section
                Section {
                    Button {
                        showingMigrationConfirm = true
                    } label: {
                        HStack {
                            Label("Flatten Vault Structure", systemImage: "rectangle.compress.vertical")
                            Spacer()
                            if isMigrating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isMigrating || vaultManager.vaultURL == nil)

                    if let summary = migrationReportSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Vault Structure")
                } footer: {
                    Text("Moves all notes from Entries/, Places/, People/, and Media/ subfolders into the vault root. Binary attachments under _attachments/ are left alone. Existing files with conflicting names at the root are skipped.")
                }
                .confirmationDialog(
                    "Flatten vault structure?",
                    isPresented: $showingMigrationConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Migrate") { runMigration() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All markdown notes will be moved into the root of your vault. This change is on disk and will appear in any synced clients (Obsidian, iCloud, etc).")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func runMigration() {
        guard let vaultURL = vaultManager.vaultURL, !isMigrating else { return }
        isMigrating = true
        migrationReportSummary = nil

        Task {
            let migrator = VaultMigrator(vaultURL: vaultURL)
            let report = await migrator.migrate()

            // Refresh in-memory caches so the UI reflects the new locations.
            _ = try? await vaultManager.loadPlaces()
            _ = try? await vaultManager.loadPeople()
            _ = try? await vaultManager.loadEntries()
            _ = try? await vaultManager.loadMedia()

            await MainActor.run {
                migrationReportSummary = report.summary
                isMigrating = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(VaultManager())
        .environmentObject(LocationService())
        .environmentObject(SignificantLocationTracker())
        .environmentObject(TemplateManager())
}
