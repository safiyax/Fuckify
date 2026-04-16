//
//  PositionTypeService.swift
//  Fuckify
//
//  Service for managing position type catalog (mirrors STIResultTypeService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionTypeService")

enum PositionTypeError: LocalizedError {
    case cannotDeleteBuiltIn
    case hasAssociatedEncounters

    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in position types cannot be deleted. You can disable them instead."
        case .hasAssociatedEncounters:
            return "This position type is used in existing encounters and cannot be deleted."
        }
    }
}

struct PositionTypeService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    func fetchAll() throws -> [SQLPositionType] {
        try database.read { db in
            try SQLPositionType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    func fetchAllIncludingDisabled() throws -> [SQLPositionType] {
        try database.read { db in
            try SQLPositionType
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    // MARK: - Create

    func create(name: String, icon: String) throws -> UUID {
        try database.write { db in
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM positionType"
            ) ?? 0
            let entity = SQLPositionType(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: true,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )
            try SQLPositionType.insert { entity }.execute(db)
            logger.info("Created position type: \(entity.id)")
            return entity.id
        }
    }

    // MARK: - Update

    func update(_ positionType: SQLPositionType) throws {
        try database.write { db in
            try SQLPositionType.update(positionType).execute(db)
            logger.info("Updated position type: \(positionType.id)")
        }
    }

    // MARK: - Delete

    func delete(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLPositionType.find(id).fetchOne(db) else { return }

            if entity.isBuiltIn {
                throw PositionTypeError.cannotDeleteBuiltIn
            }

            // Check encounter.positionTypeId references
            let encounterCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM encounter WHERE positionTypeId = ?",
                arguments: [id]
            ) ?? 0

            // Check encounterPartner.positionTypeId references
            let partnerCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM encounterPartner WHERE positionTypeId = ?",
                arguments: [id]
            ) ?? 0

            if encounterCount + partnerCount > 0 {
                throw PositionTypeError.hasAssociatedEncounters
            }

            try SQLPositionType
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted position type: \(id)")
        }
    }

    // MARK: - Toggle

    func toggle(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLPositionType.find(id).fetchOne(db) else { return }
            var updated = entity
            updated.isEnabled.toggle()

            if updated.isBuiltIn {
                // Use raw SQL for built-ins — matches CustomizationService pattern
                try db.execute(
                    sql: "UPDATE positionType SET isEnabled = ?, sortOrder = ? WHERE id = ?",
                    arguments: [updated.isEnabled, updated.sortOrder, updated.id]
                )
            } else {
                try SQLPositionType.update(updated).execute(db)
            }
            logger.info("Toggled position type \(id): isEnabled=\(updated.isEnabled)")
        }
    }

    // MARK: - Seed

    func seedDefaults() throws {
        try database.write { db in
            for positionType in SQLPositionType.builtIns {
                let existing = try SQLPositionType.find(positionType.id).fetchOne(db)
                if existing == nil {
                    try SQLPositionType.insert { positionType }.execute(db)
                }
            }
        }
    }
}

// MARK: - Dependency Key

extension PositionTypeService: DependencyKey {
    nonisolated static var liveValue: PositionTypeService { PositionTypeService() }
}

extension DependencyValues {
    var positionTypeService: PositionTypeService {
        get { self[PositionTypeService.self] }
        set { self[PositionTypeService.self] = newValue }
    }
}
