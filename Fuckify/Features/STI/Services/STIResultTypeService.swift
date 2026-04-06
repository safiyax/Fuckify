//
//  STIResultTypeService.swift
//  Fuckify
//
//  Service for managing STI test result type catalog (mirrors CustomizationService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIResultTypeService")

enum STIResultTypeError: LocalizedError {
    case cannotDeleteBuiltIn
    case hasAssociatedTests

    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in result types cannot be deleted. You can disable them instead."
        case .hasAssociatedTests:
            return "This result type has associated tests and cannot be deleted."
        }
    }
}

struct STIResultTypeService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    /// Fetch all enabled result types sorted by sortOrder
    func fetchAll() throws -> [SQLSTITestResultType] {
        try database.read { db in
            try SQLSTITestResultType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    /// Fetch all result types including disabled ones
    func fetchAllIncludingDisabled() throws -> [SQLSTITestResultType] {
        try database.read { db in
            try SQLSTITestResultType
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    // MARK: - Create

    /// Create a new custom result type
    func create(name: String, icon: String) throws -> UUID {
        try database.write { db in
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM stiTestResultType"
            ) ?? 0

            let entity = SQLSTITestResultType(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: true,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )

            try SQLSTITestResultType.insert { entity }.execute(db)
            logger.info("Created STI result type: \(entity.id)")
            return entity.id
        }
    }

    // MARK: - Delete

    /// Delete a custom result type. Throws if built-in or has associated tests.
    func delete(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLSTITestResultType.find(id).fetchOne(db) else { return }

            if entity.isBuiltIn {
                logger.warning("Attempted to delete built-in STI result type: \(id)")
                throw STIResultTypeError.cannotDeleteBuiltIn
            }

            // Check if any stiTest records reference this type
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM stiTest WHERE resultTypeId = ?",
                arguments: [id.uuidString]
            ) ?? 0

            if count > 0 {
                throw STIResultTypeError.hasAssociatedTests
            }

            try SQLSTITestResultType
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted STI result type: \(id)")
        }
    }

    // MARK: - Toggle

    /// Toggle enabled status. Updates directly in the same transaction.
    func toggle(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLSTITestResultType.find(id).fetchOne(db) else { return }
            var updated = entity
            updated.isEnabled.toggle()

            if updated.isBuiltIn {
                try db.execute(
                    sql: "UPDATE stiTestResultType SET isEnabled = ?, sortOrder = ? WHERE id = ?",
                    arguments: [updated.isEnabled, updated.sortOrder, updated.id.uuidString]
                )
            } else {
                try SQLSTITestResultType.update(updated).execute(db)
            }
            logger.info("Toggled STI result type \(id): isEnabled=\(updated.isEnabled)")
        }
    }

    // MARK: - Seed

    /// Idempotent seeding of the 3 built-in result types
    func seedDefaults() throws {
        try database.write { db in
            for resultType in SQLSTITestResultType.builtIns {
                let existing = try SQLSTITestResultType.find(resultType.id).fetchOne(db)
                if existing == nil {
                    try SQLSTITestResultType.insert { resultType }.execute(db)
                }
            }
        }
    }
}

// MARK: - Dependency Key

extension STIResultTypeService: DependencyKey {
    nonisolated static var liveValue: STIResultTypeService { STIResultTypeService() }
}

extension DependencyValues {
    var stiResultTypeService: STIResultTypeService {
        get { self[STIResultTypeService.self] }
        set { self[STIResultTypeService.self] = newValue }
    }
}
