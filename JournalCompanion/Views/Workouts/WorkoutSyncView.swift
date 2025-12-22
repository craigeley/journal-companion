//
//  WorkoutSyncView.swift
//  JournalCompanion
//
//  UI for selecting and syncing HealthKit workouts
//

import SwiftUI

struct WorkoutSyncView: View {
    @StateObject var viewModel: WorkoutSyncViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading workouts...")
                } else if viewModel.workouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts Found", systemImage: "figure.run")
                    } description: {
                        Text("No recent workouts found in HealthKit")
                    }
                } else {
                    workoutList
                }
            }
            .navigationTitle("Sync Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadWorkouts()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    private var workoutList: some View {
        List {
            Section {
                Text("Select workouts to sync from HealthKit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.filteredWorkouts) { workout in
                WorkoutRow(
                    workout: workout,
                    isAlreadySynced: viewModel.isAlreadySynced(workout.id)
                ) {
                    Task {
                        await viewModel.syncWorkout(workout)
                    }
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutData
    let isAlreadySynced: Bool
    let onSync: () -> Void

    @State private var isSyncing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: workout.workoutIcon)
                .foregroundStyle(.orange)
                .font(.title2)
                .frame(width: 32)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType)
                    .font(.headline)

                Text(workout.startDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    if let distance = workout.formattedDistance {
                        Label(distance, systemImage: "figure.run")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label(workout.formattedDuration, systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let calories = workout.calories {
                        Label("\(calories) kcal", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if workout.hasRoute {
                    Label("Route available", systemImage: "map")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            // Action button
            if isAlreadySynced {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button {
                    isSyncing = true
                    onSync()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sync")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutSyncView(
        viewModel: WorkoutSyncViewModel(
            vaultManager: VaultManager()
        )
    )
}
