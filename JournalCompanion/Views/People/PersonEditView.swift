//
//  PersonEditView.swift
//  JournalCompanion
//
//  Edit screen for existing people
//

import SwiftUI
import Contacts
import ContactsUI

struct PersonEditView: View {
    @StateObject var viewModel: PersonEditViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateManager: TemplateManager
    @State private var showBirthdayPicker = false
    @State private var tempBirthday: Date = Date()
    @State private var showContactPicker = false
    @State private var showAddAlias = false
    @State private var newAlias = ""

    var body: some View {
        NavigationStack {
            Form {
                // Read-only name section
                Section("Name") {
                    Text(viewModel.name)
                        .foregroundStyle(.primary)
                }

                // Relationship Type Section
                Section("Relationship") {
                    Picker("Type", selection: $viewModel.selectedRelationship) {
                        ForEach(RelationshipType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Pronouns Section
                if templateManager.personTemplate.isEnabled("pronouns") {
                    Section("Pronouns") {
                        TextField("e.g., they/them", text: $viewModel.pronouns)
                    }
                }

                // Contact Information Section
                Section("Contact Information") {
                    // Link to Contact button - show if ANY contact field is enabled
                    if templateManager.personTemplate.isEnabled("email")
                        || templateManager.personTemplate.isEnabled("phone")
                        || templateManager.personTemplate.isEnabled("address") {
                        Button {
                            showContactPicker = true
                        } label: {
                            HStack {
                                Image(systemName: viewModel.linkedContact != nil ? "checkmark.circle.fill" : "person.crop.circle")
                                    .foregroundStyle(viewModel.linkedContact != nil ? .green : .blue)
                                if let contact = viewModel.linkedContact {
                                    Text("\(contact.givenName) \(contact.familyName)")
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Link to Contact")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                    }

                    if templateManager.personTemplate.isEnabled("email") {
                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    if templateManager.personTemplate.isEnabled("phone") {
                        TextField("Phone", text: $viewModel.phone)
                            .keyboardType(.phonePad)
                    }

                    if templateManager.personTemplate.isEnabled("address") {
                        TextField("Address", text: $viewModel.address, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }

                // Birthday Section
                if templateManager.personTemplate.isEnabled("birthday") {
                    Section("Birthday") {
                        if let birthday = viewModel.birthday {
                            HStack {
                                Text(formatBirthday(birthday))
                                Spacer()
                                Button("Change") {
                                    // Initialize temp date from existing birthday
                                    if let existingDate = Calendar.current.date(from: birthday) {
                                        tempBirthday = existingDate
                                    }
                                    showBirthdayPicker = true
                                }
                                .foregroundStyle(.blue)
                            }
                            Button("Remove Birthday") {
                                viewModel.birthday = nil
                            }
                            .foregroundStyle(.red)
                        } else {
                            Button("Add Birthday") {
                                tempBirthday = Date()
                                showBirthdayPicker = true
                            }
                        }
                    }
                }

                // Aliases Section
                if templateManager.personTemplate.isEnabled("aliases") {
                    Section("Aliases") {
                        ForEach(viewModel.aliases.indices, id: \.self) { index in
                            HStack {
                                Text(viewModel.aliases[index])
                                Spacer()
                                Button(action: {
                                    viewModel.aliases.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        Button("Add Alias") {
                            showAddAlias = true
                        }
                    }
                }

                // Notes Section
                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 120)
                        .font(.body)
                }
            }
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.saveChanges() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
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
            .sheet(isPresented: $showBirthdayPicker) {
                NavigationStack {
                    Form {
                        DatePicker(
                            "Birthday",
                            selection: $tempBirthday,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
                    .navigationTitle("Select Birthday")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showBirthdayPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                // Convert Date to DateComponents
                                let components = Calendar.current.dateComponents([.year, .month, .day], from: tempBirthday)
                                viewModel.birthday = components
                                showBirthdayPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerRepresentable { contact in
                    viewModel.linkContact(contact)
                }
            }
            .alert("Add Alias", isPresented: $showAddAlias) {
                TextField("Alias", text: $newAlias)
                Button("Add") {
                    let trimmed = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !viewModel.aliases.contains(trimmed) {
                        viewModel.aliases.append(trimmed)
                    }
                    newAlias = ""
                }
                Button("Cancel", role: .cancel) {
                    newAlias = ""
                }
            } message: {
                Text("Enter an alternative name for this person")
            }
        }
    }

    private func formatBirthday(_ birthday: DateComponents) -> String {
        guard birthday.month != nil, birthday.day != nil else {
            return "Unknown"
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()

        if birthday.year != nil {
            // Full birthdate with year - show date and calculate age
            guard let birthDate = calendar.date(from: birthday) else {
                return "Unknown"
            }

            formatter.dateFormat = "MMMM d, yyyy"
            let dateString = formatter.string(from: birthDate)

            // Calculate age
            let now = Date()
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
            if let age = ageComponents.year {
                return "\(dateString) (age \(age))"
            } else {
                return dateString
            }
        } else {
            // Only month/day available - show without year
            var components = birthday
            components.year = calendar.component(.year, from: Date())

            if let date = calendar.date(from: components) {
                formatter.dateFormat = "MMMM d"
                return formatter.string(from: date)
            }
            return "Unknown"
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let templateManager = TemplateManager()
    let samplePerson = Person(
        id: "alice-smith",
        name: "Alice Smith",
        pronouns: "she/her",
        relationshipType: .friend,
        tags: ["close", "college"],
        email: "alice@example.com",
        phone: "+1-555-123-4567",
        address: "123 Main St, San Francisco, CA",
        birthday: DateComponents(year: 1990, month: 3, day: 15),
        metDate: Date(),
        socialMedia: ["instagram": "alicesmith"],
        color: "rgb(72,133,237)",
        photoFilename: nil,
        aliases: [],
        content: "Met in college. Great friend and always up for coffee."
    )
    let viewModel = PersonEditViewModel(person: samplePerson, vaultManager: vaultManager, templateManager: templateManager)
    PersonEditView(viewModel: viewModel)
}
