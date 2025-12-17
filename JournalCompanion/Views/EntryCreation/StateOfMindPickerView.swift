//
//  StateOfMindPickerView.swift
//  JournalCompanion
//
//  Picker interface for capturing State of Mind
//

import SwiftUI
import HealthKit

struct StateOfMindPickerView: View {
    @Binding var selectedValence: Double
    @Binding var selectedLabels: [HKStateOfMind.Label]
    @Binding var selectedAssociations: [HKStateOfMind.Association]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Valence Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("How are you feeling?")
                                .font(.headline)
                            Spacer()
                            Text(valenceEmoji)
                                .font(.title)
                        }

                        Slider(value: $selectedValence, in: -1.0...1.0, step: 0.1)

                        HStack {
                            Text("Unpleasant")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Pleasant")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Overall Feeling")
                }

                // Labels Section
                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(StateOfMindConstants.allLabels, id: \.label) { item in
                            EmotionChip(
                                label: item.display,
                                category: item.category,
                                isSelected: selectedLabels.contains(item.label)
                            ) {
                                toggleLabel(item.label)
                            }
                        }
                    }
                } header: {
                    Text("Emotions")
                } footer: {
                    Text("Select emotions that describe your current state")
                        .font(.caption)
                }

                // Associations Section
                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(StateOfMindConstants.allAssociations, id: \.association) { item in
                            AssociationChip(
                                label: item.display,
                                icon: item.icon,
                                isSelected: selectedAssociations.contains(item.association)
                            ) {
                                toggleAssociation(item.association)
                            }
                        }
                    }
                } header: {
                    Text("Related To")
                } footer: {
                    Text("What's influencing how you feel?")
                        .font(.caption)
                }
            }
            .navigationTitle("State of Mind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Reset to initial state
                        selectedValence = 0.0
                        selectedLabels = []
                        selectedAssociations = []
                        dismiss()
                    }
                }
            }
        }
    }

    private var valenceEmoji: String {
        switch selectedValence {
        case 0.6...1.0: return "😊"
        case 0.2..<0.6: return "🙂"
        case -0.2..<0.2: return "😐"
        case -0.6..<(-0.2): return "🙁"
        default: return "😢"
        }
    }

    private func toggleLabel(_ label: HKStateOfMind.Label) {
        if let index = selectedLabels.firstIndex(of: label) {
            selectedLabels.remove(at: index)
        } else {
            selectedLabels.append(label)
        }
    }

    private func toggleAssociation(_ association: HKStateOfMind.Association) {
        if let index = selectedAssociations.firstIndex(of: association) {
            selectedAssociations.remove(at: index)
        } else {
            selectedAssociations.append(association)
        }
    }
}

// MARK: - Emotion Chip

struct EmotionChip: View {
    let label: String
    let category: String  // "positive", "negative", "neutral"
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return category == "positive" ? .green.opacity(0.2) :
                   category == "negative" ? .red.opacity(0.2) :
                   .gray.opacity(0.2)
        } else {
            return .gray.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        if isSelected {
            return category == "positive" ? .green :
                   category == "negative" ? .red :
                   .primary
        } else {
            return .secondary
        }
    }

    private var borderColor: Color {
        category == "positive" ? .green :
        category == "negative" ? .red :
        .gray
    }
}

// MARK: - Association Chip

struct AssociationChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .purple : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.purple, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}
