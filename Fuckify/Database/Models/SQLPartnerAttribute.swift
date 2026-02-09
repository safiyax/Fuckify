//
//  SQLPartnerAttribute.swift
//  Fuckify
//
//  Custom attribute system for partners
//

import Foundation
import SQLiteData

// MARK: - Partner Attribute Type

@Table("partnerAttributeType")
struct SQLPartnerAttributeType: Identifiable {
    let id: UUID
    var name: String
    var fieldType: String               // "text", "boolean", "date", "enum"
    var icon: String                    // SF Symbol name
    var isBuiltIn: Bool                 // true for defaults, false for custom
    var isEnabled: Bool                 // visibility toggle
    var sortOrder: Int                  // display order
    var dateAdded: Date
    var enumChoices: String?            // JSON array for enum types: ["Negative","Positive","Unknown"]
    
    nonisolated init(
        id: UUID = UUID(),
        name: String,
        fieldType: PartnerAttributeFieldType,
        icon: String,
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        dateAdded: Date = Date(),
        enumChoices: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.fieldType = fieldType.rawValue
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.dateAdded = dateAdded
        self.enumChoices = enumChoices?.toJSONString()
    }
    
    // Helper to get parsed field type
    var parsedFieldType: PartnerAttributeFieldType {
        PartnerAttributeFieldType(rawValue: fieldType) ?? .text
    }
    
    // Helper to get parsed enum choices
    var parsedEnumChoices: [String] {
        guard let json = enumChoices else { return [] }
        return json.fromJSONString() ?? []
    }
}

// MARK: - Partner Attribute Value

@Table("partnerAttributeValue")
struct SQLPartnerAttributeValue: Identifiable {
    let id: UUID
    var partnerId: UUID
    var attributeTypeId: UUID
    var value: String                   // Stored as text, parsed by fieldType
    
    nonisolated init(
        id: UUID = UUID(),
        partnerId: UUID,
        attributeTypeId: UUID,
        value: String
    ) {
        self.id = id
        self.partnerId = partnerId
        self.attributeTypeId = attributeTypeId
        self.value = value
    }
}

// MARK: - Field Type Enum

enum PartnerAttributeFieldType: String, Codable, CaseIterable {
    case text = "text"
    case boolean = "boolean"
    case date = "date"
    case enumType = "enum"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .boolean: return "Yes/No"
        case .date: return "Date"
        case .enumType: return "Multiple Choice"
        }
    }
}

// MARK: - Built-in HIV Status Enum

enum HIVStatus: String, Codable, CaseIterable {
    case negative = "Negative"
    case positive = "Positive"
    case unknown = "Unknown"
    
    var displayName: String {
        self.rawValue
    }
}

// MARK: - Attribute with Value (for display)

struct PartnerAttributeWithValue: Identifiable {
    let type: SQLPartnerAttributeType
    let value: SQLPartnerAttributeValue?
    
    var id: UUID { type.id }
    
    var displayValue: String {
        guard let value = value else { return "Not set" }
        
        switch type.parsedFieldType {
        case .text:
            return value.value.isEmpty ? "Not set" : value.value
        case .boolean:
            return value.value == "true" ? "Yes" : "No"
        case .date:
            if let date = ISO8601DateFormatter().date(from: value.value) {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
            return "Not set"
        case .enumType:
            return value.value.isEmpty ? "Not set" : value.value
        }
    }
}

// MARK: - Predefined UUIDs for Built-in Attributes

extension SQLPartnerAttributeType {
    nonisolated static let lastSTITestId = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    nonisolated static let hivStatusId = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    nonisolated static let onBirthControlId = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!
    nonisolated static let onPrepId = UUID(uuidString: "00000000-0000-0000-0000-000000000204")!  // Migrated from partner.isOnPrep
}

// MARK: - JSON Helpers

extension Array where Element == String {
    nonisolated func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

extension String {
    nonisolated func fromJSONString() -> [String]? {
        guard let data = self.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return array
    }
}
