//
//  CheckInView.swift
//  JournalCompanionWatch
//
//  Main view with large check-in button
//

import SwiftUI

struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 12) {
                // Status indicator
                statusBadge

                Spacer()

                // Check-in button
                checkInButton

                Spacer()

                // Today's count
                todayCountView
            }
            .padding()

            // Confirmation overlay
            if viewModel.showConfirmation {
                confirmationOverlay
            }
        }
        .sheet(isPresented: $viewModel.showNoteInput) {
            QuickNoteInputView(viewModel: viewModel)
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.locationStatusIcon)
                .font(.caption2)

            Text(viewModel.locationStatusText)
                .font(.caption2)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.2))
        )
    }

    private var statusColor: Color {
        switch viewModel.locationStatus {
        case .acquired:
            return .green
        case .denied, .failed:
            return .orange
        case .requesting:
            return .blue
        default:
            return .secondary
        }
    }

    // MARK: - Check-In Button

    private var checkInButton: some View {
        Button(action: {
            viewModel.startCheckIn()
        }) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)

                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing)

        Text("Check In")
            .font(.headline)
            .padding(.top, 4)
    }

    // MARK: - Today Count

    private var todayCountView: some View {
        VStack(spacing: 2) {
            Text("\(viewModel.todayCount) today")
                .font(.caption)
                .foregroundColor(.secondary)

            // Show pending indicator if any
            if viewModel.pendingCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("\(viewModel.pendingCount) pending")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Checked In!")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .transition(.opacity)
    }
}

#Preview {
    CheckInView()
}
