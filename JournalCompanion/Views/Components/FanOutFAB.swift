//
//  FanOutFAB.swift
//  JournalCompanion
//
//  Animated arc fan-out FAB for entry type selection
//

import SwiftUI

struct FanOutFAB: View {
    @Binding var isExpanded: Bool
    let onTextEntry: () -> Void
    let onAudioEntry: () -> Void
    let onWorkoutSync: () -> Void

    // Animation constants
    private let arcRadius: CGFloat = 100
    private let buttonSize: CGFloat = 50
    private let mainButtonSize: CGFloat = 56

    var body: some View {
        ZStack {
            // Background overlay (dismisses when tapped)
            if isExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }

            // Action buttons in arc pattern
            actionButton(
                icon: "square.and.pencil",
                color: .blue,
                position: arcPosition(angle: 60),
                accessibilityLabel: "Text Entry",
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                    onTextEntry()
                }
            )

            actionButton(
                icon: "waveform",
                color: .red,
                position: arcPosition(angle: 90),
                accessibilityLabel: "Audio Entry",
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                    onAudioEntry()
                }
            )

            actionButton(
                icon: "figure.run",
                color: .orange,
                position: arcPosition(angle: 120),
                accessibilityLabel: "Sync Workouts",
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                    onWorkoutSync()
                }
            )

            // Main FAB button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: mainButtonSize, height: mainButtonSize)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .accessibilityLabel(isExpanded ? "Close menu" : "Create entry")
            .accessibilityHint(isExpanded ? "Closes the entry type menu" : "Opens menu to select entry type")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func actionButton(
        icon: String,
        color: Color,
        position: CGSize,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(color)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .offset(isExpanded ? position : .zero)
        .scaleEffect(isExpanded ? 1.0 : 0.0)
        .opacity(isExpanded ? 1.0 : 0.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Creates a \(accessibilityLabel.lowercased())")
    }

    // MARK: - Geometry Helpers

    /// Convert polar coordinates (angle, radius) to cartesian (x, y) offset
    private func arcPosition(angle: Double) -> CGSize {
        let radians = angle * .pi / 180
        let x = arcRadius * cos(radians)
        let y = -arcRadius * sin(radians)  // Negative because SwiftUI y increases downward
        return CGSize(width: x, height: y)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isExpanded = false

    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                FanOutFAB(
                    isExpanded: $isExpanded,
                    onTextEntry: { print("Text entry") },
                    onAudioEntry: { print("Audio entry") },
                    onWorkoutSync: { print("Workout sync") }
                )
                .padding(.trailing, 20)
            }
        }
        .padding(.bottom, 70)
    }
}
