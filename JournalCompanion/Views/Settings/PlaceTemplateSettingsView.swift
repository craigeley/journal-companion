//
//  PlaceTemplateSettingsView.swift
//  JournalCompanion
//
//  Configure which fields appear in place creation/editing
//

import SwiftUI

struct PlaceTemplateSettingsView: View {
    @EnvironmentObject var templateManager: TemplateManager
    @State private var template: PlaceTemplate
    @State private var hasChanges = false
    @State private var showResetConfirmation = false
    @Environment(\.dismiss) var dismiss

    init() {
        _template = State(initialValue: .defaultTemplate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Configure which fields appear when creating or editing places. Empty fields will still be written to the file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Field Configuration
                Section("Fields") {
                    ForEach(template.fields.sorted(by: { $0.order < $1.order }), id: \.id) { field in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.displayName)
                                if field.isRequired {
                                    Text("Required")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if !field.isRequired {
                                Toggle("", isOn: Binding(
                                    get: { field.isEnabled },
                                    set: { newValue in
                                        if let index = template.fields.firstIndex(where: { $0.id == field.id }) {
                                            template.fields[index].isEnabled = newValue
                                            hasChanges = true
                                        }
                                    }
                                ))
                                    .labelsHidden()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Default Values
                Section("Default Values") {
                    // Default tags
                    if let tagsField = template.field(for: "tags"),
                       tagsField.isEnabled,
                       case .tags(let tags) = tagsField.defaultValue {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default Tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(tags.joined(separator: ", "))
                        }
                    }

                    // Default callout
                    if let calloutField = template.field(for: "callout"),
                       case .callout(let calloutType) = calloutField.defaultValue {
                        LabeledContent("Default Type", value: calloutType.capitalized)
                    }
                }

                // Actions
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .navigationTitle("Place Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(!hasChanges)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                template = templateManager.placeTemplate
            }
            .confirmationDialog(
                "Reset place template to defaults?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    templateManager.resetPlaceTemplate()
                    template = templateManager.placeTemplate
                    hasChanges = false
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func saveTemplate() {
        do {
            try templateManager.savePlaceTemplate(template)
            hasChanges = false
            dismiss()
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PlaceTemplateSettingsView()
            .environmentObject(TemplateManager())
    }
}
