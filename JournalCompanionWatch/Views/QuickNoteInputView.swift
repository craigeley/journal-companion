//
//  QuickNoteInputView.swift
//  JournalCompanionWatch
//
//  Quick note entry with dictation support
//

import SwiftUI

struct QuickNoteInputView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @State private var noteText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Location status
                locationStatus

                // Note input
                TextField("Add a note...", text: $noteText, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .padding(.vertical, 4)

                // Action buttons
                HStack(spacing: 12) {
                    Button("Skip") {
                        viewModel.skipNote()
                    }
                    .foregroundColor(.secondary)

                    Button("Done") {
                        viewModel.completeCheckIn(note: noteText)
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Note")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelCheckIn()
                }
            }
        }
    }

    private var locationStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.hasLocation ? "location.fill" : "location.slash")
                .font(.caption)

            Text(viewModel.hasLocation ? "Location captured" : "No location")
                .font(.caption)
        }
        .foregroundColor(viewModel.hasLocation ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(viewModel.hasLocation ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
        )
    }
}

#Preview {
    QuickNoteInputView(viewModel: CheckInViewModel())
}
