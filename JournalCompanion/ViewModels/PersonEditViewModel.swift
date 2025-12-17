//
//  PersonEditViewModel.swift
//  JournalCompanion
//
//  View model for creating and editing people
//

import Foundation
import SwiftUI
import Combine
import Contacts
import ContactsUI

@MainActor
class PersonEditViewModel: ObservableObject {
    // Creation-specific field
    @Published var personName: String = ""

    // Editable fields (both modes)
    @Published var pronouns: String = ""
    @Published var selectedRelationship: RelationshipType = .friend
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var address: String = ""
    @Published var birthday: DateComponents?
    @Published var aliases: [String] = []
    @Published var tags: [String] = []
    @Published var notes: String = ""

    // Display field (edit mode only)
    @Published var name: String = ""

    // Contact linking
    @Published var linkedContact: CNContact?

    // UI state
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var nameError: String?

    private let originalPerson: Person?
    let vaultManager: VaultManager
    let templateManager: TemplateManager

    var isCreating: Bool { originalPerson == nil }

    init(
        person: Person? = nil,
        vaultManager: VaultManager,
        templateManager: TemplateManager,
        initialName: String? = nil
    ) {
        self.originalPerson = person
        self.vaultManager = vaultManager
        self.templateManager = templateManager

        if let person = person {
            // EDIT MODE - pre-populate all fields from existing person
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
        } else {
            // CREATE MODE - apply defaults and initial values
            if let initialName = initialName {
                self.personName = initialName
            }

            // Apply template defaults
            applyTemplateDefaults()
        }
    }

    /// Apply default values from template to form fields (creation mode only)
    private func applyTemplateDefaults() {
        let template = templateManager.personTemplate

        // Apply default relationship type
        if let defaultRel = template.defaultValue(for: "relationship"),
           case .relationship(let relType) = defaultRel {
            selectedRelationship = relType
        }

        // Apply default tags
        if let defaultTags = template.defaultValue(for: "tags"),
           case .tags(let tagList) = defaultTags {
            tags = tagList
        } else {
            tags = ["person"]  // Fallback default
        }
    }

    /// Validation - name is required and must not conflict (pure computed property)
    var isValid: Bool {
        if isCreating {
            let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Name required
            guard !trimmedName.isEmpty else {
                return false
            }

            // Check for duplicate
            let sanitized = Person.sanitizeFilename(trimmedName)
            let exists = vaultManager.people.contains { $0.id == sanitized }

            return !exists
        } else {
            // Edit mode - always valid
            return true
        }
    }

    /// Update validation error message (call this explicitly, not during view rendering)
    func validateName() {
        guard isCreating else { return }

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

        // In creation mode, import name if not set
        if isCreating && personName.isEmpty {
            personName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        }

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

    /// Unified save method - handles both creation and editing
    func save() async -> Bool {
        guard isValid else { return false }
        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            let writer = PersonWriter(vaultURL: vaultURL, templateManager: templateManager)

            if isCreating {
                // CREATE MODE - write new person
                let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedId = Person.sanitizeFilename(trimmedName)

                let newPerson = Person(
                    id: sanitizedId,
                    name: trimmedName,
                    pronouns: pronouns.isEmpty ? nil : pronouns,
                    relationshipType: selectedRelationship,
                    tags: tags,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address,
                    birthday: birthday,
                    metDate: nil,
                    color: nil,
                    photoFilename: nil,
                    aliases: aliases,
                    content: notes
                )

                try await writer.write(person: newPerson)
            } else {
                // EDIT MODE - update existing person
                let updatedPerson = Person(
                    id: originalPerson!.id,  // Keep same ID to avoid file renaming
                    name: originalPerson!.name,  // Keep same name to avoid file renaming
                    pronouns: pronouns.isEmpty ? nil : pronouns,
                    relationshipType: selectedRelationship,
                    tags: tags,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address,
                    birthday: birthday,
                    metDate: originalPerson!.metDate,
                    color: originalPerson!.color,
                    photoFilename: originalPerson!.photoFilename,
                    aliases: aliases,
                    content: notes
                )

                try await writer.update(person: updatedPerson)
            }

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

    /// Check if person has unsaved changes (edit mode only)
    var hasChanges: Bool {
        guard let original = originalPerson else { return false }

        let pronounsChanged = (pronouns.isEmpty ? nil : pronouns) != original.pronouns
        let emailChanged = (email.isEmpty ? nil : email) != original.email
        let phoneChanged = (phone.isEmpty ? nil : phone) != original.phone
        let addressChanged = (address.isEmpty ? nil : address) != original.address
        let relationshipChanged = selectedRelationship != original.relationshipType
        let notesChanged = notes != original.content
        let birthdayChanged = birthday != original.birthday
        let tagsChanged = tags != original.tags
        let aliasesChanged = aliases != original.aliases

        return pronounsChanged || emailChanged || phoneChanged || addressChanged ||
               relationshipChanged || notesChanged || birthdayChanged || tagsChanged ||
               aliasesChanged
    }
}
