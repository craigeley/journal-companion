//
//  Template.swift
//  JournalCompanion
//
//  Data models for configurable field templates
//

import Foundation

// MARK: - Base Template Field Protocol
protocol TemplateField: Sendable {
    var id: String { get }
    var key: String { get }  // YAML key name
    var displayName: String { get }
    var isEnabled: Bool { get set }
    var isRequired: Bool { get }
    var order: Int { get }
}

// MARK: - Person Template Field
struct PersonTemplateField: TemplateField, Identifiable, Codable, Sendable {
    let id: String
    let key: String
    let displayName: String
    var isEnabled: Bool
    let isRequired: Bool
    var order: Int
    var defaultValue: PersonFieldValue?

    enum PersonFieldValue: Codable, Sendable {
        case text(String)
        case relationship(RelationshipType)
        case tags([String])
        case aliases([String])
        case date(Date?)  // For metDate
        case dateComponents(DateComponents?)  // For birthday
        case socialMedia([String: String])
        case color(String?)

        var stringValue: String? {
            switch self {
            case .text(let str): return str
            case .relationship(let rel): return rel.rawValue
            case .tags(let arr): return arr.isEmpty ? nil : arr.joined(separator: ", ")
            case .aliases(let arr): return arr.isEmpty ? nil : arr.joined(separator: ", ")
            case .date: return nil
            case .dateComponents: return nil
            case .socialMedia(let dict): return dict.isEmpty ? nil : String(describing: dict)
            case .color(let str): return str
            }
        }
    }
}

// MARK: - Place Template Field
struct PlaceTemplateField: TemplateField, Identifiable, Codable, Sendable {
    let id: String
    let key: String
    let displayName: String
    var isEnabled: Bool
    let isRequired: Bool
    var order: Int
    var defaultValue: PlaceFieldValue?

    enum PlaceFieldValue: Codable, Sendable {
        case text(String)
        case tags([String])
        case callout(String)
        case aliases([String])
        case color(String?)
        case url(String?)

        var stringValue: String? {
            switch self {
            case .text(let str): return str
            case .tags(let arr): return arr.isEmpty ? nil : arr.joined(separator: ", ")
            case .callout(let str): return str
            case .aliases(let arr): return arr.isEmpty ? nil : arr.joined(separator: ", ")
            case .color(let str): return str
            case .url(let str): return str
            }
        }
    }
}

// MARK: - Person Template
struct PersonTemplate: Codable, Sendable {
    var fields: [PersonTemplateField]

    /// Default template with all available fields
    static var defaultTemplate: PersonTemplate {
        PersonTemplate(fields: [
            // Required fields (always enabled)
            PersonTemplateField(
                id: "relationship",
                key: "relationship",
                displayName: "Relationship Type",
                isEnabled: true,
                isRequired: true,
                order: 0,
                defaultValue: .relationship(.friend)
            ),

            // Optional fields (can be toggled)
            PersonTemplateField(
                id: "pronouns",
                key: "pronouns",
                displayName: "Pronouns",
                isEnabled: true,
                isRequired: false,
                order: 1,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "tags",
                key: "tags",
                displayName: "Tags",
                isEnabled: true,
                isRequired: false,
                order: 2,
                defaultValue: .tags(["person"])  // Default tag
            ),
            PersonTemplateField(
                id: "email",
                key: "email",
                displayName: "Email",
                isEnabled: true,
                isRequired: false,
                order: 3,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "phone",
                key: "phone",
                displayName: "Phone",
                isEnabled: true,
                isRequired: false,
                order: 4,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "address",
                key: "address",
                displayName: "Address",
                isEnabled: true,
                isRequired: false,
                order: 5,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "birthday",
                key: "birthday",
                displayName: "Birthday",
                isEnabled: true,
                isRequired: false,
                order: 6,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "met_date",
                key: "met_date",
                displayName: "Date Met",
                isEnabled: false,  // Disabled by default
                isRequired: false,
                order: 7,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "color",
                key: "color",
                displayName: "Color",
                isEnabled: false,
                isRequired: false,
                order: 8,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "photo",
                key: "photo",
                displayName: "Photo",
                isEnabled: false,
                isRequired: false,
                order: 9,
                defaultValue: nil
            ),
            PersonTemplateField(
                id: "aliases",
                key: "aliases",
                displayName: "Aliases",
                isEnabled: true,
                isRequired: false,
                order: 10,
                defaultValue: .aliases([])
            )
            // Note: socialMedia fields are dynamic and handled separately
        ])
    }

    /// Get field by key
    func field(for key: String) -> PersonTemplateField? {
        fields.first { $0.key == key }
    }

    /// Check if field is enabled
    func isEnabled(_ key: String) -> Bool {
        field(for: key)?.isEnabled ?? false
    }

    /// Get default value for field
    func defaultValue(for key: String) -> PersonTemplateField.PersonFieldValue? {
        field(for: key)?.defaultValue
    }
}

// MARK: - Place Template
struct PlaceTemplate: Codable, Sendable {
    var fields: [PlaceTemplateField]

    /// Default template with all available fields
    static var defaultTemplate: PlaceTemplate {
        PlaceTemplate(fields: [
            // Required fields
            PlaceTemplateField(
                id: "callout",
                key: "callout",
                displayName: "Type",
                isEnabled: true,
                isRequired: true,
                order: 0,
                defaultValue: .callout("place")
            ),

            // Optional fields
            PlaceTemplateField(
                id: "location",
                key: "location",
                displayName: "Location (Coordinates)",
                isEnabled: true,
                isRequired: false,
                order: 1,
                defaultValue: nil
            ),
            PlaceTemplateField(
                id: "addr",
                key: "addr",
                displayName: "Address",
                isEnabled: true,
                isRequired: false,
                order: 2,
                defaultValue: nil
            ),
            PlaceTemplateField(
                id: "tags",
                key: "tags",
                displayName: "Tags",
                isEnabled: true,
                isRequired: false,
                order: 3,
                defaultValue: .tags(["place"])  // Default tag
            ),
            PlaceTemplateField(
                id: "pin",
                key: "pin",
                displayName: "Custom Pin Icon",
                isEnabled: false,
                isRequired: false,
                order: 4,
                defaultValue: nil
            ),
            PlaceTemplateField(
                id: "color",
                key: "color",
                displayName: "Color",
                isEnabled: false,
                isRequired: false,
                order: 5,
                defaultValue: nil
            ),
            PlaceTemplateField(
                id: "url",
                key: "url",
                displayName: "Website URL",
                isEnabled: false,
                isRequired: false,
                order: 6,
                defaultValue: nil
            ),
            PlaceTemplateField(
                id: "aliases",
                key: "aliases",
                displayName: "Aliases",
                isEnabled: true,
                isRequired: false,
                order: 7,
                defaultValue: .aliases([])
            )
        ])
    }

    /// Get field by key
    func field(for key: String) -> PlaceTemplateField? {
        fields.first { $0.key == key }
    }

    /// Check if field is enabled
    func isEnabled(_ key: String) -> Bool {
        field(for: key)?.isEnabled ?? false
    }

    /// Get default value for field
    func defaultValue(for key: String) -> PlaceTemplateField.PlaceFieldValue? {
        field(for: key)?.defaultValue
    }
}
