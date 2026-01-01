//
//  JournalCompanionApp.swift
//  JournalCompanion
//
//  Main app entry point
//

import SwiftUI
import UserNotifications

@main
struct JournalCompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vaultManager = VaultManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var visitTracker = SignificantLocationTracker()
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var searchCoordinator = SearchCoordinator()
    @StateObject private var visitNotificationCoordinator = VisitNotificationCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
                .environmentObject(locationService)
                .environmentObject(visitTracker)
                .environmentObject(templateManager)
                .environmentObject(searchCoordinator)
                .environmentObject(visitNotificationCoordinator)
                .onAppear {
                    // Set the notification delegate
                    UNUserNotificationCenter.current().delegate = appDelegate
                    // Connect coordinator to app delegate for notification handling
                    appDelegate.visitCoordinator = visitNotificationCoordinator
                }
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var visitCoordinator: VisitNotificationCoordinator?

    // Handle notification tap when app is in background/terminated
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Check if this is a visit notification
        if let latitude = userInfo["visitLatitude"] as? Double,
           let longitude = userInfo["visitLongitude"] as? Double,
           let arrivalTimestamp = userInfo["visitArrivalDate"] as? TimeInterval,
           let departureTimestamp = userInfo["visitDepartureDate"] as? TimeInterval {

            let visitData = VisitNotificationData(
                latitude: latitude,
                longitude: longitude,
                arrivalDate: Date(timeIntervalSince1970: arrivalTimestamp),
                departureDate: Date(timeIntervalSince1970: departureTimestamp),
                placeName: userInfo["placeName"] as? String
            )

            // Notify coordinator on main thread
            Task { @MainActor in
                visitCoordinator?.handleVisitNotification(visitData)
            }
        }

        completionHandler()
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
