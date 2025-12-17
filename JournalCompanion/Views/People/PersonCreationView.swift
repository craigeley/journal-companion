//
//  PersonCreationView.swift
//  JournalCompanion
//
//  View for creating new person records
//

import SwiftUI
import Contacts
import ContactsUI

struct PersonCreationView: View {
    @StateObject var viewModel: PersonCreationViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFieldFocused: Bool
    @State private var showContactPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Name Section (Required)
                Section {
                    TextField("Person Name", text: $viewModel.personName)
                        .focused($isNameFieldFocused)
                } header: {
                    Text("Name")
                } footer: {
                    if let error = viewModel.nameError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                // Contact Integration Section
                Section("Contact") {
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
                Section("Pronouns (Optional)") {
                    TextField("e.g., they/them", text: $viewModel.pronouns)
                }

                // Contact Info (auto-populated from linked contact)
                if viewModel.linkedContact != nil {
                    Section("Contact Information") {
                        if !viewModel.contactEmail.isEmpty {
                            LabeledContent("Email", value: viewModel.contactEmail)
                        }
                        if !viewModel.contactPhone.isEmpty {
                            LabeledContent("Phone", value: viewModel.contactPhone)
                        }
                        if !viewModel.contactAddress.isEmpty {
                            LabeledContent("Address") {
                                Text(viewModel.contactAddress)
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        if let birthday = viewModel.contactBirthday {
                            LabeledContent("Birthday") {
                                Text(formatBirthdayPreview(birthday))
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Notes Section (Optional)
                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createPerson()
                            if viewModel.creationSucceeded {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if viewModel.personName.isEmpty {
                    isNameFieldFocused = true
                }
            }
            .onChange(of: viewModel.personName) { _, _ in
                viewModel.validateName()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerRepresentable { contact in
                    viewModel.linkContact(contact)
                }
            }
        }
    }

    private func formatBirthdayPreview(_ birthday: DateComponents) -> String {
        guard birthday.month != nil, birthday.day != nil else {
            return "Unknown"
        }
        var components = birthday
        components.year = Calendar.current.component(.year, from: Date())
        if let date = Calendar.current.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date)
        }
        return "Unknown"
    }
}
