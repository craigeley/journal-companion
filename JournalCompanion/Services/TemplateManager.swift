//
//  TemplateManager.swift
//  JournalCompanion
//
//  Manages persistence and retrieval of user-configured templates
//

import Foundation
import Combine

@MainActor
class TemplateManager: ObservableObject {
    @Published var personTemplate: PersonTemplate
    @Published var placeTemplate: PlaceTemplate

    private let userDefaults = UserDefaults.standard
    private static let personTemplateKey = "personTemplate"
    private static let placeTemplateKey = "placeTemplate"

    init() {
        // Load saved templates with migration for new fields
        self.personTemplate = TemplateManager.loadPersonTemplate()
        self.placeTemplate = TemplateManager.loadPlaceTemplate()
    }

    // MARK: - Person Template

    /// Load person template from UserDefaults with automatic migration
    private static func loadPersonTemplate() -> PersonTemplate {
        guard let data = UserDefaults.standard.data(forKey: personTemplateKey),
              let savedTemplate = try? JSONDecoder().decode(PersonTemplate.self, from: data) else {
            return .defaultTemplate
        }

        // Migrate: add any new fields from default template that aren't in saved template
        let defaultTemplate = PersonTemplate.defaultTemplate
        var migratedFields = savedTemplate.fields

        for defaultField in defaultTemplate.fields {
            if !migratedFields.contains(where: { $0.id == defaultField.id }) {
                // New field - add it with default settings
                migratedFields.append(defaultField)
            }
        }

        return PersonTemplate(fields: migratedFields)
    }

    /// Save person template to UserDefaults
    func savePersonTemplate(_ template: PersonTemplate) throws {
        let data = try JSONEncoder().encode(template)
        userDefaults.set(data, forKey: Self.personTemplateKey)
        self.personTemplate = template
    }

    /// Reset person template to defaults
    func resetPersonTemplate() {
        userDefaults.removeObject(forKey: Self.personTemplateKey)
        self.personTemplate = .defaultTemplate
    }

    // MARK: - Place Template

    /// Load place template from UserDefaults with automatic migration
    private static func loadPlaceTemplate() -> PlaceTemplate {
        guard let data = UserDefaults.standard.data(forKey: placeTemplateKey),
              let savedTemplate = try? JSONDecoder().decode(PlaceTemplate.self, from: data) else {
            return .defaultTemplate
        }

        // Migrate: add any new fields from default template that aren't in saved template
        let defaultTemplate = PlaceTemplate.defaultTemplate
        var migratedFields = savedTemplate.fields

        for defaultField in defaultTemplate.fields {
            if !migratedFields.contains(where: { $0.id == defaultField.id }) {
                // New field - add it with default settings
                migratedFields.append(defaultField)
            }
        }

        return PlaceTemplate(fields: migratedFields)
    }

    /// Save place template to UserDefaults
    func savePlaceTemplate(_ template: PlaceTemplate) throws {
        let data = try JSONEncoder().encode(template)
        userDefaults.set(data, forKey: Self.placeTemplateKey)
        self.placeTemplate = template
    }

    /// Reset place template to defaults
    func resetPlaceTemplate() {
        userDefaults.removeObject(forKey: Self.placeTemplateKey)
        self.placeTemplate = .defaultTemplate
    }
}
