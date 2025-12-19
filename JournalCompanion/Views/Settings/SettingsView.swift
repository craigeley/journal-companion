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
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(VaultManager())
        .environmentObject(LocationService())
        .environmentObject(SignificantLocationTracker())
        .environmentObject(TemplateManager())
}
