//
//  PersonTemplateSettingsView.swift
//  JournalCompanion
//
//  Configure which fields appear in person creation/editing
//

import SwiftUI

struct PersonTemplateSettingsView: View {
    @EnvironmentObject var templateManager: TemplateManager
    @State private var template: PersonTemplate
    @State private var hasChanges = false
    @State private var showResetConfirmation = false
    @Environment(\.dismiss) var dismiss

    init() {
        // Initialize with current template (will be overridden in .onAppear)
        _template = State(initialValue: .defaultTemplate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Configure which fields appear when creating or editing people. Empty fields will still be written to the file.")
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

                // Default Values Section
                Section("Default Values") {
                    // Default tags
                    if let tagsField = template.field(for: "tags"),
                       tagsField.isEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default Tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if case .tags(let tags) = tagsField.defaultValue {
                                Text(tags.joined(separator: ", "))
                            }

                            Text("Default: person")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Default relationship type
                    if let relField = template.field(for: "relationship"),
                       case .relationship(let relType) = relField.defaultValue {
                        LabeledContent("Default Relationship", value: relType.rawValue.capitalized)
                    }
                }

                // Actions
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .navigationTitle("Person Template")
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
                template = templateManager.personTemplate
            }
            .confirmationDialog(
                "Reset person template to defaults?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    templateManager.resetPersonTemplate()
                    template = templateManager.personTemplate
                    hasChanges = false
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func saveTemplate() {
        do {
            try templateManager.savePersonTemplate(template)
            hasChanges = false
            dismiss()
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PersonTemplateSettingsView()
            .environmentObject(TemplateManager())
    }
}
