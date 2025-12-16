//
//  PersonCreationViewModel.swift
//  JournalCompanion
//
//  View model for person creation
//

import Foundation
import SwiftUI
import Contacts
import Combine

@MainActor
class PersonCreationViewModel: ObservableObject {
    // Form fields
    @Published var personName: String = ""
    @Published var pronouns: String = ""
    @Published var selectedRelationship: RelationshipType = .friend
    @Published var notes: String = ""

    // Contact integration
    @Published var linkedContact: CNContact?
    @Published var contactEmail: String = ""
    @Published var contactPhone: String = ""
    @Published var contactAddress: String = ""

    // UI state
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var nameError: String?
    @Published var creationSucceeded: Bool = false

    let vaultManager: VaultManager

    init(vaultManager: VaultManager, initialName: String? = nil) {
        self.vaultManager = vaultManager

        // Pre-populate name if provided
        if let name = initialName {
            self.personName = name
        }
    }

    /// Validation - name is required and must not conflict (pure computed property)
    var isValid: Bool {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Name required
        guard !trimmedName.isEmpty else {
            return false
        }

        // Check for duplicate
        let sanitized = Person.sanitizeFilename(trimmedName)
        let exists = vaultManager.people.contains { $0.id == sanitized }

        return !exists
    }

    /// Update validation error message (call this explicitly, not during view rendering)
    func validateName() {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            nameError = "Name is required"
            return
        }

        let sanitized = Person.sanitizeFilename(trimmedName)
        let exists = vaultManager.people.contains { $0.id == sanitized }

        if exists {
            nameError = "A person with this name already exists"
        } else {
            nameError = nil
        }
    }

    /// Link to system contact and import contact info
    func linkContact(_ contact: CNContact) {
        linkedContact = contact

        // Import name if not set
        if personName.isEmpty {
            personName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        }

        // Import email (first available)
        if let email = contact.emailAddresses.first {
            contactEmail = email.value as String
        }

        // Import phone (first available)
        if let phone = contact.phoneNumbers.first {
            contactPhone = phone.value.stringValue
        }

        // Import address (first available)
        if let address = contact.postalAddresses.first {
            let addr = address.value
            let formatter = CNPostalAddressFormatter()
            contactAddress = formatter.string(from: addr)
        }
    }

    /// Create and save person
    func createPerson() async {
        guard isValid else { return }
        guard let vaultURL = vaultManager.vaultURL else {
            errorMessage = "No vault configured"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedId = Person.sanitizeFilename(trimmedName)

            // Create new person
            let newPerson = Person(
                id: sanitizedId,
                name: trimmedName,
                pronouns: pronouns.isEmpty ? nil : pronouns,
                relationshipType: selectedRelationship,
                tags: [],  // Start with no tags
                email: contactEmail.isEmpty ? nil : contactEmail,
                phone: contactPhone.isEmpty ? nil : contactPhone,
                address: contactAddress.isEmpty ? nil : contactAddress,
                birthday: nil,  // MVP: can be added later via edit
                metDate: nil,   // MVP: can be added later via edit
                socialMedia: [:],  // Start with no social media
                color: nil,
                photoFilename: nil,  // MVP: can be added later
                content: notes
            )

            // Write person file
            let writer = PersonWriter(vaultURL: vaultURL)
            try await writer.write(person: newPerson)

            // Reload people in VaultManager
            _ = try await vaultManager.loadPeople()

            // Success
            creationSucceeded = true
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    /// Clear form after successful creation
    private func clearForm() {
        personName = ""
        pronouns = ""
        selectedRelationship = .friend
        notes = ""
        linkedContact = nil
        contactEmail = ""
        contactPhone = ""
        contactAddress = ""
    }
}
