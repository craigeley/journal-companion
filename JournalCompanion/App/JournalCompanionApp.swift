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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(visitTracker)
        }
    }
}
