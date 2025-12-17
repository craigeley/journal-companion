//
//  PersonEditViewModel.swift
//  JournalCompanion
//
//  View model for editing existing people
//

import Foundation
import SwiftUI
import Combine
import Contacts
import ContactsUI

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
    @Published var aliases: [String]
    @Published var tags: [String]
    @Published var notes: String

    // Contact linking
    @Published var linkedContact: CNContact?

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?

    private let originalPerson: Person
    let vaultManager: VaultManager
    let templateManager: TemplateManager

    init(person: Person, vaultManager: VaultManager, templateManager: TemplateManager) {
        self.originalPerson = person
        self.vaultManager = vaultManager
        self.templateManager = templateManager

        // Pre-populate with existing data
        self.name = person.name
        self.pronouns = person.pronouns ?? ""
        self.selectedRelationship = person.relationshipType
        self.email = person.email ?? ""
        self.phone = person.phone ?? ""
        self.address = person.address ?? ""
        self.birthday = person.birthday
        self.aliases = person.aliases
        self.tags = person.tags
        self.notes = person.content
    }

    /// Link to system contact and import contact info
    func linkContact(_ contact: CNContact) {
        linkedContact = contact

        // Import email (first available)
        if let email = contact.emailAddresses.first {
            self.email = email.value as String
        }

        // Import phone (first available)
        if let phone = contact.phoneNumbers.first {
            self.phone = formatPhoneNumber(phone.value.stringValue)
        }

        // Import address (first available)
        if let address = contact.postalAddresses.first {
            let addr = address.value
            let formatter = CNPostalAddressFormatter()
            self.address = formatter.string(from: addr)
        }

        // Import birthday (if available)
        if let birthday = contact.birthday {
            self.birthday = birthday
        }
    }

    /// Format phone number to match existing format: +1 (XXX) XXX-XXXX
    private func formatPhoneNumber(_ rawNumber: String) -> String {
        // Remove all non-digit characters except leading +
        let hasPlus = rawNumber.hasPrefix("+")
        let digitsOnly = rawNumber.filter { $0.isNumber }

        // Check if it's a US number with country code (11 digits starting with 1)
        if digitsOnly.hasPrefix("1") && digitsOnly.count == 11 {
            let index1 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 1)
            let index4 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 4)
            let index7 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 7)

            let areaCode = digitsOnly[index1..<index4]
            let firstPart = digitsOnly[index4..<index7]
            let secondPart = digitsOnly[index7...]

            return "+1 (\(areaCode)) \(firstPart)-\(secondPart)"
        }

        // Check if it's a 10-digit US number without country code
        if digitsOnly.count == 10 {
            let index3 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)
            let index6 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)

            let areaCode = digitsOnly[..<index3]
            let firstPart = digitsOnly[index3..<index6]
            let secondPart = digitsOnly[index6...]

            return "+1 (\(areaCode)) \(firstPart)-\(secondPart)"
        }

        // For non-US numbers, return as-is with + prefix if it had one
        return hasPlus ? rawNumber : digitsOnly
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
                tags: tags,  // Use edited tags
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                birthday: birthday,
                metDate: originalPerson.metDate,  // Not editable yet
                color: originalPerson.color,
                photoFilename: originalPerson.photoFilename,
                aliases: aliases,  // Use edited aliases
                content: notes
            )

            // Update the person file
            let writer = PersonWriter(vaultURL: vaultURL, templateManager: templateManager)
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
        let tagsChanged = tags != originalPerson.tags

        return pronounsChanged || emailChanged || phoneChanged || addressChanged ||
               relationshipChanged || notesChanged || birthdayChanged || tagsChanged
    }
}
