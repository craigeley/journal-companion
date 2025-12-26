//
//  JournalCompanionApp.swift
//  JournalCompanion
//
//  Main app entry point
//

import SwiftUI

@main
struct JournalCompanionApp: App {
    @StateObject private var vaultManager = VaultManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var visitTracker = SignificantLocationTracker()
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var searchCoordinator = SearchCoordinator()
    @StateObject private var watchSyncService = WatchSyncService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(visitTracker)
                .environmentObject(templateManager)
                .environmentObject(searchCoordinator)
                .environmentObject(watchSyncService)
                .onAppear {
                    // Configure watch sync service with vault manager
                    watchSyncService.configure(vaultManager: vaultManager)
                }
        }
    }
}
