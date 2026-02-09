//
//  PartnerAttributeService.swift
//  Fuckify
//
//  Service for managing custom partner attributes
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

/// Service layer for partner attribute types and values
struct PartnerAttributeService {
    @Dependency(\.defaultDatabase) var database
    
    // Synthesized memberwise init is nonisolated
    nonisolated init() {}
    
    // MARK: - Attribute Types
    
    /// Fetch all attribute types, ordered by sortOrder
    func fetchAllAttributeTypes() throws -> [SQLPartnerAttributeType] {
        try database.read { db in
            try SQLPartnerAttributeType
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch only enabled attribute types
    func fetchEnabledAttributeTypes() throws -> [SQLPartnerAttributeType] {
        try database.read { db in
            try SQLPartnerAttributeType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch attribute type by ID
    func fetchAttributeType(id: UUID) throws -> SQLPartnerAttributeType? {
        try database.read { db in
            try SQLPartnerAttributeType.find(id).fetchOne(db)
        }
    }
    
    /// Create a new custom attribute type
    func createAttributeType(
        name: String,
        fieldType: PartnerAttributeFieldType,
        icon: String,
        enumChoices: [String]? = nil,
        isEnabled: Bool = true
    ) throws -> UUID {
        try database.write { db in
            // Get max sort order
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM partnerAttributeType"
            ) ?? 0
            
            let entity = SQLPartnerAttributeType(
                id: UUID(),
                name: name,
                fieldType: fieldType,
                icon: icon,
                isBuiltIn: false,
                isEnabled: isEnabled,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date(),
                enumChoices: enumChoices
            )
            
            try SQLPartnerAttributeType.insert { entity }
                .execute(db)
            
            return entity.id
        }
    }
    
    /// Update an attribute type
    func updateAttributeType(_ entity: SQLPartnerAttributeType) throws {
        try database.write { db in
            // Built-ins can only update isEnabled and sortOrder
            if entity.isBuiltIn {
                try db.execute(
                    sql: """
                    UPDATE partnerAttributeType 
                    SET isEnabled = ?, sortOrder = ?
                    WHERE id = ?
                    """,
                    arguments: [entity.isEnabled, entity.sortOrder, entity.id]
                )
            } else {
                // Custom types can update everything
                try SQLPartnerAttributeType.update(entity).execute(db)
            }
        }
    }
    
    /// Delete a custom attribute type (built-ins cannot be deleted)
    func deleteAttributeType(id: UUID) throws {
        try database.write { db in
            // Check if it's built-in
            if let entity = try SQLPartnerAttributeType.find(id).fetchOne(db),
               entity.isBuiltIn {
                throw PartnerAttributeError.cannotDeleteBuiltIn
            }
            
            // Delete the attribute type (cascade will delete values)
            try SQLPartnerAttributeType
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
        }
    }
    
    /// Toggle attribute type enabled status
    func toggleAttributeType(id: UUID) throws {
        try database.write { db in
            if let entity = try SQLPartnerAttributeType.find(id).fetchOne(db) {
                var updated = entity
                updated.isEnabled.toggle()
                
                // Update directly (avoid reentrant database access)
                try SQLPartnerAttributeType.update(updated).execute(db)
            }
        }
    }
    
    // MARK: - Attribute Values
    
    /// Fetch all attribute values for a partner
    func fetchValues(forPartner partnerId: UUID) throws -> [SQLPartnerAttributeValue] {
        try database.read { db in
            try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) }
                .fetchAll(db)
        }
    }
    
    /// Fetch attributes with values for a partner
    func fetchAttributesWithValues(forPartner partnerId: UUID) throws -> [PartnerAttributeWithValue] {
        try database.read { db in
            // Fetch enabled attribute types directly (avoid reentrant database access)
            let types = try SQLPartnerAttributeType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
            
            // Fetch values for this partner directly (avoid reentrant database access)
            let values = try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) }
                .fetchAll(db)
            
            // Create lookup dictionary
            let valuesByType = Dictionary(uniqueKeysWithValues: values.map { ($0.attributeTypeId, $0) })
            
            return types.map { type in
                PartnerAttributeWithValue(
                    type: type,
                    value: valuesByType[type.id]
                )
            }
        }
    }
    
    /// Set attribute value for a partner
    func setValue(
        forPartner partnerId: UUID,
        attributeTypeId: UUID,
        value: String
    ) throws {
        try database.write { db in
            // Check if value already exists
            let existing = try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) && $0.attributeTypeId.eq(attributeTypeId) }
                .fetchOne(db)
            
            if let existing = existing {
                // Update existing
                var updated = existing
                updated.value = value
                try SQLPartnerAttributeValue.update(updated).execute(db)
            } else {
                // Insert new
                let newValue = SQLPartnerAttributeValue(
                    id: UUID(),
                    partnerId: partnerId,
                    attributeTypeId: attributeTypeId,
                    value: value
                )
                try SQLPartnerAttributeValue.insert { newValue }.execute(db)
            }
        }
    }
    
    /// Delete attribute value
    func deleteValue(forPartner partnerId: UUID, attributeTypeId: UUID) throws {
        try database.write { db in
            try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) && $0.attributeTypeId.eq(attributeTypeId) }
                .delete()
                .execute(db)
        }
    }
    
    /// Delete all values for a partner
    func deleteAllValues(forPartner partnerId: UUID) throws {
        try database.write { db in
            try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) }
                .delete()
                .execute(db)
        }
    }
    
    // MARK: - Helpers
    
    /// Get specific built-in attribute value
    func getBuiltInValue(
        forPartner partnerId: UUID,
        attributeId: UUID
    ) throws -> String? {
        try database.read { db in
            try SQLPartnerAttributeValue
                .where { $0.partnerId.eq(partnerId) && $0.attributeTypeId.eq(attributeId) }
                .fetchOne(db)?
                .value
        }
    }
}

// MARK: - Dependency Key

extension PartnerAttributeService: DependencyKey {
    nonisolated static var liveValue: PartnerAttributeService { PartnerAttributeService() }
}

extension DependencyValues {
    var partnerAttributeService: PartnerAttributeService {
        get { self[PartnerAttributeService.self] }
        set { self[PartnerAttributeService.self] = newValue }
    }
}

// MARK: - Errors

enum PartnerAttributeError: LocalizedError {
    case cannotDeleteBuiltIn
    case invalidFieldType
    case invalidValue
    
    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in attributes cannot be deleted. You can disable them instead."
        case .invalidFieldType:
            return "Invalid field type specified."
        case .invalidValue:
            return "Invalid value for this field type."
        }
    }
}
