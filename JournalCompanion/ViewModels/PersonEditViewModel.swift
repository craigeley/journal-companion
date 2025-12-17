//
//  PersonEditViewModel.swift
//  JournalCompanion
//
//  View model for editing existing people
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PersonEditViewModel: ObservableObject {
    // Read-only name (displayed but not editable in v1 to avoid file renaming complexity)
    @Published var name: String

    // Editable fields
    @Published var pronouns: String
    @Published var selectedRelationship: RelationshipType
    @Published var email: String
    @Published var phone: String
    @Published var address: String
    @Published var birthday: DateComponents?
    @Published var notes: String

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?

    private let originalPerson: Person
    let vaultManager: VaultManager

    init(person: Person, vaultManager: VaultManager) {
        self.originalPerson = person
        self.vaultManager = vaultManager

        // Pre-populate with existing data
        self.name = person.name
        self.pronouns = person.pronouns ?? ""
        self.selectedRelationship = person.relationshipType
        self.email = person.email ?? ""
        self.phone = person.phone ?? ""
        self.address = person.address ?? ""
        self.birthday = person.birthday
        self.notes = person.content
    }

    /// Save changes to the person
    func saveChanges() async -> Bool {
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            // Create updated person with same ID (filename)
            let updatedPerson = Person(
                id: originalPerson.id,  // Keep same ID to update existing file
                name: originalPerson.name,  // Name not editable in v1
                pronouns: pronouns.isEmpty ? nil : pronouns,
                relationshipType: selectedRelationship,
                tags: originalPerson.tags,  // Tags not editable yet
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                birthday: birthday,
                metDate: originalPerson.metDate,  // Not editable yet
                socialMedia: originalPerson.socialMedia,  // Not editable yet
                color: originalPerson.color,
                photoFilename: originalPerson.photoFilename,
                content: notes
            )

            // Update the person file
            let writer = PersonWriter(vaultURL: vaultURL)
            try await writer.update(person: updatedPerson)

            // Reload people in VaultManager to reflect changes
            _ = try await vaultManager.loadPeople()

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Check if person has unsaved changes
    var hasChanges: Bool {
        let pronounsChanged = (pronouns.isEmpty ? nil : pronouns) != originalPerson.pronouns
        let emailChanged = (email.isEmpty ? nil : email) != originalPerson.email
        let phoneChanged = (phone.isEmpty ? nil : phone) != originalPerson.phone
        let addressChanged = (address.isEmpty ? nil : address) != originalPerson.address
        let relationshipChanged = selectedRelationship != originalPerson.relationshipType
        let notesChanged = notes != originalPerson.content
        let birthdayChanged = birthday != originalPerson.birthday

        return pronounsChanged || emailChanged || phoneChanged || addressChanged ||
               relationshipChanged || notesChanged || birthdayChanged
    }
}
