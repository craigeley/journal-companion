//
//  ContactPickerRepresentable.swift
//  JournalCompanion
//
//  UIKit wrapper for CNContactPickerViewController
//

import SwiftUI
import Contacts
import ContactsUI

struct ContactPickerRepresentable: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Request specific contact properties we need
        picker.displayedPropertyKeys = [
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactPostalAddressesKey,
            CNContactBirthdayKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (CNContact) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Refetch contact with all keys we need
            let store = CNContactStore()
            let keysToFetch = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactEmailAddressesKey,
                CNContactPhoneNumbersKey,
                CNContactPostalAddressesKey,
                CNContactBirthdayKey
            ] as [CNKeyDescriptor]

            do {
                let fullContact = try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
                onSelect(fullContact)
            } catch {
                print("⚠️ Failed to fetch full contact: \(error)")
                // Fallback to original contact
                onSelect(contact)
            }
            // Contact picker dismisses itself automatically
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Contact picker dismisses itself automatically
        }
    }
}
