//
//  HealthKitAuthView.swift
//  JournalCompanion
//
//  HealthKit authorization prompt for State of Mind
//

import SwiftUI
import HealthKit

struct HealthKitAuthView: View {
    @State private var authStatus: HKAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss

    private let healthKitService = HealthKitService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.pink)

                Text("Health Integration")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("JournalCompanion can save your emotional state to Apple Health, allowing you to track your well-being over time.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                switch authStatus {
                case .notDetermined:
                    Button {
                        Task {
                            await requestAuthorization()
                        }
                    } label: {
                        if isRequesting {
                            ProgressView()
                        } else {
                            Text("Enable Health Integration")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)

                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)

                case .sharingAuthorized:
                    Label("Health Integration Enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                case .sharingDenied:
                    VStack(spacing: 12) {
                        Label("Health Access Denied", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)

                        Text("To enable, go to Settings > Health > Data Access & Devices > JournalCompanion")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                @unknown default:
                    EmptyView()
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Health Integration")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await checkAuthStatus()
            }
        }
    }

    private func checkAuthStatus() async {
        print("🔍 Checking HealthKit authorization status...")
        authStatus = await healthKitService.authorizationStatus()
        print("🔍 Auth status result: \(authStatus.rawValue)")
    }

    private func requestAuthorization() async {
        print("🚀 User tapped 'Enable Health Integration'")
        isRequesting = true
        errorMessage = nil

        do {
            try await healthKitService.requestAuthorization()
            print("✅ Authorization request succeeded")
            await checkAuthStatus()
        } catch {
            print("❌ Authorization request failed: \(error)")
            errorMessage = error.localizedDescription
        }

        isRequesting = false
    }
}
