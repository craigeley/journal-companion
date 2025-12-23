//
//  TranscriptEditView.swift
//  JournalCompanion
//
//  View for editing audio transcript time ranges
//

import SwiftUI

struct TranscriptEditView: View {
    @StateObject var viewModel: TranscriptEditViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($viewModel.timeRanges) { $range in
                        VStack(alignment: .leading, spacing: 8) {
                            // Timestamp (read-only)
                            Text(viewModel.formatTimeRange(range.start, range.end))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Editable transcript text
                            TextField("Transcript", text: $range.text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...10)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Transcript Segments")
                } footer: {
                    Text("Edit the transcript text. Timestamps cannot be changed.")
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .alert("Save Error", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") {
                    viewModel.saveError = nil
                }
            } message: {
                if let error = viewModel.saveError {
                    Text(error)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
}
