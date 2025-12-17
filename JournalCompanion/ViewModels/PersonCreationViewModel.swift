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
    @Published var contactBirthday: DateComponents?

    // UI state
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var nameError: String?
    @Published var creationSucceeded: Bool = false

    let vaultManager: VaultManager
    let templateManager: TemplateManager

    init(vaultManager: VaultManager, templateManager: TemplateManager, initialName: String? = nil) {
        self.vaultManager = vaultManager
        self.templateManager = templateManager

        // Pre-populate name if provided
        if let name = initialName {
            self.personName = name
        }

        // Apply template defaults
        applyTemplateDefaults()
    }

    /// Apply default values from template to form fields
    private func applyTemplateDefaults() {
        let template = templateManager.personTemplate

        // Apply default relationship type
        if let defaultRel = template.defaultValue(for: "relationship"),
           case .relationship(let relType) = defaultRel {
            selectedRelationship = relType
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
            contactPhone = formatPhoneNumber(phone.value.stringValue)
        }

        // Import address (first available)
        if let address = contact.postalAddresses.first {
            let addr = address.value
            let formatter = CNPostalAddressFormatter()
            contactAddress = formatter.string(from: addr)
        }

        // Import birthday (if available)
        if let birthday = contact.birthday {
            // CNContact.birthday is already DateComponents with month/day (and possibly year)
            contactBirthday = birthday
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

            // Get default tags from template
            let defaultTags: [String] = {
                if let tagsField = templateManager.personTemplate.field(for: "tags"),
                   case .tags(let tags) = tagsField.defaultValue {
                    return tags
                }
                return ["person"]  // Fallback default
            }()

            // Create new person
            let newPerson = Person(
                id: sanitizedId,
                name: trimmedName,
                pronouns: pronouns.isEmpty ? nil : pronouns,
                relationshipType: selectedRelationship,
                tags: defaultTags,  // Use template default
                email: contactEmail.isEmpty ? nil : contactEmail,
                phone: contactPhone.isEmpty ? nil : contactPhone,
                address: contactAddress.isEmpty ? nil : contactAddress,
                birthday: contactBirthday,  // Use contact birthday if available
                metDate: nil,   // MVP: can be added later via edit
                color: nil,
                photoFilename: nil,  // MVP: can be added later
                aliases: [],  // Start with no aliases
                content: notes
            )

            // Write person file
            let writer = PersonWriter(vaultURL: vaultURL, templateManager: templateManager)
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
        contactBirthday = nil
    }
}
