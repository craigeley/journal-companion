//
//  DailyNoteCreationView.swift
//  JournalCompanion
//
//  UI for creating a daily note for a specific date
//

import SwiftUI

struct DailyNoteCreationView: View {
    @StateObject var viewModel: DailyNoteCreationViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Date picker section
                Section {
                    DatePicker(
                        "Date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        viewModel.checkDayFileExists()
                    }
                } header: {
                    Text("Select Date")
                } footer: {
                    if viewModel.dayFileExists {
                        Label("A daily note already exists for this date", systemImage: "checkmark.circle")
                            .foregroundStyle(.orange)
                    } else {
                        Text("Choose a date to create a daily note for")
                    }
                }

                // Status section
                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Weather metadata will be included if a location is configured in Settings", systemImage: "cloud.sun")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Info")
                }
            }
            .navigationTitle("Create Daily Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createDailyNote()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(viewModel.isCreating || viewModel.dayFileExists)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyNoteCreationView(
        viewModel: DailyNoteCreationViewModel(vaultManager: VaultManager())
    )
}
