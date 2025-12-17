//
//  PersonEditView.swift
//  JournalCompanion
//
//  Edit screen for existing people
//

import SwiftUI

struct PersonEditView: View {
    @StateObject var viewModel: PersonEditViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showBirthdayPicker = false
    @State private var tempBirthday: Date = Date()

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
                Section("Pronouns") {
                    TextField("e.g., they/them", text: $viewModel.pronouns)
                }

                // Contact Information Section
                Section("Contact Information") {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    TextField("Phone", text: $viewModel.phone)
                        .keyboardType(.phonePad)

                    TextField("Address", text: $viewModel.address, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Birthday Section
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
        content: "Met in college. Great friend and always up for coffee."
    )
    let viewModel = PersonEditViewModel(person: samplePerson, vaultManager: vaultManager)
    return PersonEditView(viewModel: viewModel)
}
