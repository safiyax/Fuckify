//
//  CustomizationService.swift
//  Fuckify
//
//  Service for managing customizable activity types and protection methods
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "CustomizationService")

/// Service layer for customizable activity and protection method types
struct CustomizationService {
    @Dependency(\.defaultDatabase) var database
    
    // MARK: - Activity Types
    
    /// Fetch all activity types, ordered by sortOrder then name
    func fetchAllActivityTypes() throws -> [SQLActivityTypeEntity] {
        try database.read { db in
            try SQLActivityTypeEntity
                .order { $0.sortOrder.asc() }
                .order { $0.name.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch only enabled activity types
    func fetchEnabledActivityTypes() throws -> [SQLActivityTypeEntity] {
        try database.read { db in
            try SQLActivityTypeEntity
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .order { $0.name.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch activity type by ID
    func fetchActivityType(id: UUID) throws -> SQLActivityTypeEntity? {
        try database.read { db in
            try SQLActivityTypeEntity.find(id).fetchOne(db)
        }
    }
    
    /// Create a new custom activity type
    func createActivityType(
        name: String,
        icon: String,
        isEnabled: Bool = true
    ) throws -> UUID {
        try database.write { db in
            // Get max sort order using raw SQL
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM activityType"
            ) ?? 0
            
            let entity = SQLActivityTypeEntity(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: isEnabled,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )
            
            try SQLActivityTypeEntity.insert { entity }
                .execute(db)
            
            logger.info("Created activity type: \(entity.id)")
            return entity.id
        }
    }
    
    /// Update an activity type (only name, icon, enabled status for built-ins)
    func updateActivityType(_ entity: SQLActivityTypeEntity) throws {
        try database.write { db in
            // If it's built-in, only allow updating isEnabled and sortOrder
            if entity.isBuiltIn {
                try db.execute(
                    sql: """
                    UPDATE activityType 
                    SET isEnabled = ?, sortOrder = ?
                    WHERE id = ?
                    """,
                    arguments: [entity.isEnabled, entity.sortOrder, entity.id]
                )
            } else {
                // Custom types can update everything except isBuiltIn
                try SQLActivityTypeEntity.update(entity).execute(db)
            }
        }
    }
    
    /// Delete a custom activity type (built-ins cannot be deleted)
    func deleteActivityType(id: UUID) throws {
        try database.write { db in
            // Check if it's built-in
            if let entity = try SQLActivityTypeEntity.find(id).fetchOne(db),
               entity.isBuiltIn {
                logger.warning("Attempted to delete built-in activity type: \(id)")
                throw CustomizationError.cannotDeleteBuiltIn
            }
            
            // Delete the activity type
            try SQLActivityTypeEntity
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted activity type: \(id)")
        }
    }
    
    /// Toggle activity type enabled status
    func toggleActivityType(id: UUID) throws {
        try database.write { db in
            if let entity = try SQLActivityTypeEntity.find(id).fetchOne(db) {
                var updated = entity
                updated.isEnabled.toggle()
                
                // Update directly in this transaction to avoid re-entrant error
                if updated.isBuiltIn {
                    try db.execute(
                        sql: """
                        UPDATE activityType 
                        SET isEnabled = ?, sortOrder = ?
                        WHERE id = ?
                        """,
                        arguments: [updated.isEnabled, updated.sortOrder, updated.id]
                    )
                } else {
                    try SQLActivityTypeEntity.update(updated).execute(db)
                }
            }
        }
    }
    
    // MARK: - Protection Method Types
    
    /// Fetch all protection method types, ordered by sortOrder then name
    func fetchAllProtectionMethods() throws -> [SQLProtectionMethodEntity] {
        try database.read { db in
            try SQLProtectionMethodEntity
                .order { $0.sortOrder.asc() }
                .order { $0.name.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch only enabled protection method types
    func fetchEnabledProtectionMethods() throws -> [SQLProtectionMethodEntity] {
        try database.read { db in
            try SQLProtectionMethodEntity
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .order { $0.name.asc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch protection method type by ID
    func fetchProtectionMethod(id: UUID) throws -> SQLProtectionMethodEntity? {
        try database.read { db in
            try SQLProtectionMethodEntity.find(id).fetchOne(db)
        }
    }
    
    /// Create a new custom protection method type
    func createProtectionMethod(
        name: String,
        icon: String,
        isEnabled: Bool = true
    ) throws -> UUID {
        try database.write { db in
            // Get max sort order using raw SQL
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM protectionMethodType"
            ) ?? 0
            
            let entity = SQLProtectionMethodEntity(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: isEnabled,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )
            
            try SQLProtectionMethodEntity.insert { entity }
                .execute(db)
            
            logger.info("Created protection method: \(entity.id)")
            return entity.id
        }
    }
    
    /// Update a protection method type
    func updateProtectionMethod(_ entity: SQLProtectionMethodEntity) throws {
        try database.write { db in
            // If it's built-in, only allow updating isEnabled and sortOrder
            if entity.isBuiltIn {
                try db.execute(
                    sql: """
                    UPDATE protectionMethodType 
                    SET isEnabled = ?, sortOrder = ?
                    WHERE id = ?
                    """,
                    arguments: [entity.isEnabled, entity.sortOrder, entity.id]
                )
            } else {
                // Custom types can update everything except isBuiltIn
                try SQLProtectionMethodEntity.update(entity).execute(db)
            }
        }
    }
    
    /// Delete a custom protection method type (built-ins cannot be deleted)
    func deleteProtectionMethod(id: UUID) throws {
        try database.write { db in
            // Check if it's built-in
            if let entity = try SQLProtectionMethodEntity.find(id).fetchOne(db),
               entity.isBuiltIn {
                logger.warning("Attempted to delete built-in protection method: \(id)")
                throw CustomizationError.cannotDeleteBuiltIn
            }
            
            // Delete the protection method type
            try SQLProtectionMethodEntity
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted protection method: \(id)")
        }
    }
    
    /// Toggle protection method type enabled status
    func toggleProtectionMethod(id: UUID) throws {
        try database.write { db in
            if let entity = try SQLProtectionMethodEntity.find(id).fetchOne(db) {
                var updated = entity
                updated.isEnabled.toggle()
                
                // Update directly in this transaction to avoid re-entrant error
                if updated.isBuiltIn {
                    try db.execute(
                        sql: """
                        UPDATE protectionMethodType 
                        SET isEnabled = ?, sortOrder = ?
                        WHERE id = ?
                        """,
                        arguments: [updated.isEnabled, updated.sortOrder, updated.id]
                    )
                } else {
                    try SQLProtectionMethodEntity.update(updated).execute(db)
                }
            }
        }
    }
    
    // MARK: - Migration Helpers
    
    /// Seed default activity types from enum (idempotent - won't duplicate)
    func seedDefaultActivityTypes() throws {
        try database.write { db in
            for (index, activityType) in SQLActivityType.allCases.enumerated() {
                // Check if already exists
                let existing = try SQLActivityTypeEntity
                    .find(activityType.predefinedUUID)
                    .fetchOne(db)
                
                if existing == nil {
                    let entity = activityType.toEntity(sortOrder: index, isEnabled: true)
                    try SQLActivityTypeEntity.insert { entity }.execute(db)
                }
            }
        }
    }
    
    /// Seed default protection method types from enum (idempotent)
    func seedDefaultProtectionMethods() throws {
        try database.write { db in
            for (index, protectionMethod) in SQLProtectionMethod.allCases.enumerated() {
                // Check if already exists
                let existing = try SQLProtectionMethodEntity
                    .find(protectionMethod.predefinedUUID)
                    .fetchOne(db)
                
                if existing == nil {
                    let entity = protectionMethod.toEntity(sortOrder: index, isEnabled: true)
                    try SQLProtectionMethodEntity.insert { entity }.execute(db)
                }
            }
        }
    }
}

// MARK: - Errors

enum CustomizationError: LocalizedError {
    case cannotDeleteBuiltIn
    case duplicateName
    case invalidIcon
    
    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in types cannot be deleted. You can disable them instead."
        case .duplicateName:
            return "An item with this name already exists."
        case .invalidIcon:
            return "Invalid SF Symbol name."
        }
    }
}
