//
//  EncounterService.swift
//  Fuckify
//
//  Database service for Encounter CRUD operations using SQLiteData
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "EncounterService")

/// Complete encounter data with all relationships loaded
/// Used to avoid N+1 query problems
struct EncounterWithRelationships: Identifiable {
    let encounter: SQLEncounter
    let partners: [SQLPartner]
    let activityEntities: [SQLActivityTypeEntity]
    let protectionEntities: [SQLProtectionMethodEntity]
    /// Maps partnerId → SQLPositionType (nil if no position set for that partner)
    let partnerPositions: [UUID: SQLPositionType]
    /// The user's own position for this encounter
    let myPosition: SQLPositionType?

    var id: UUID { encounter.id }

    init(
        encounter: SQLEncounter,
        partners: [SQLPartner],
        activityEntities: [SQLActivityTypeEntity] = [],
        protectionEntities: [SQLProtectionMethodEntity] = [],
        partnerPositions: [UUID: SQLPositionType] = [:],
        myPosition: SQLPositionType? = nil
    ) {
        self.encounter = encounter
        self.partners = partners
        self.activityEntities = activityEntities
        self.protectionEntities = protectionEntities
        self.partnerPositions = partnerPositions
        self.myPosition = myPosition
    }
}

/// Service layer for Encounter database operations
/// Uses SQLiteData's query builder and GRDB database connection
struct EncounterService {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.partnerService) var partnerService
    
    // Synthesized memberwise init is nonisolated
    nonisolated init() {}
    
    // MARK: - Create
    
    /// Create an encounter with partners, activities, and protection methods
    /// All operations in a single transaction
    func create(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        partnerPositionTypeIDs: [UUID: UUID?] = [:],
        myPositionTypeId: UUID? = nil,
        activityTypeIDs: [UUID],
        protectionMethodIDs: [UUID]
    ) throws -> UUID {
        try database.write { db in
            let encounterID = encounterDraft.id ?? UUID()
            let encounter = SQLEncounter(
                id: encounterID,
                date: encounterDraft.date,
                duration: encounterDraft.duration,
                location: encounterDraft.location,
                notes: encounterDraft.notes,
                rating: encounterDraft.rating,
                reachedOrgasm: encounterDraft.reachedOrgasm,
                positionTypeId: myPositionTypeId,
                dateAdded: encounterDraft.dateAdded
            )

            try SQLEncounter.insert { encounter }.execute(db)

            // Link partners with positions
            for partnerID in partnerIDs {
                let positionId = partnerPositionTypeIDs[partnerID] ?? nil
                let junction = SQLEncounterPartner(
                    id: UUID(),
                    encounterId: encounterID,
                    partnerId: partnerID,
                    positionTypeId: positionId
                )
                try SQLEncounterPartner.insert { junction }.execute(db)
            }

            // Link activities
            try EncounterActivity.insert {
                activityTypeIDs.map { activityTypeID in
                    EncounterActivity(id: UUID(), encounterId: encounterID, activityTypeId: activityTypeID)
                }
            }.execute(db)

            // Link protection methods
            try EncounterProtectionMethod.insert {
                protectionMethodIDs.map { methodID in
                    EncounterProtectionMethod(id: UUID(), encounterId: encounterID, protectionMethodId: methodID)
                }
            }.execute(db)

            // Update lastEncounterDate for all partners
            if let encounterDate = encounter.date {
                for partnerID in partnerIDs {
                    guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else { continue }
                    if partner.lastEncounterDate == nil || partner.lastEncounterDate! < encounterDate {
                        partner.lastEncounterDate = encounterDate
                        try SQLPartner.update(partner).execute(db)
                    }
                }
            }

            logger.info("Created encounter: \(encounterID) with \(partnerIDs.count) partners")
            return encounterID
        }
    }

    // MARK: - Read
    
    /// Fetch all encounters sorted by date (descending)
    func fetchAll() throws -> [SQLEncounter] {
        try database.read { db in
            try SQLEncounter
                .order { $0.date.desc() }
                .fetchAll(db)
        }
    }
    
    /// Fetch all encounters with relationships in optimized batches
    /// Avoids N+1 query problem by loading all relationships upfront
    func fetchAllWithRelationships() throws -> [EncounterWithRelationships] {
        try database.read { db in
            // 1. Fetch all encounters
            let encounters = try SQLEncounter
                .order { $0.date.desc() }
                .fetchAll(db)
            
            guard !encounters.isEmpty else { return [] }
            
            let encounterIDs = encounters.map(\.id)
            
            // 2. Batch load ALL partner relationships
            let partnerJunctions = try SQLEncounterPartner
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            let allPartnerIDs = Set(partnerJunctions.map(\.partnerId))
            let allPartners = try SQLPartner
                .where { allPartnerIDs.contains($0.id) }
                .fetchAll(db)
            
            // Create lookup dictionary
            let partnersByID = Dictionary(uniqueKeysWithValues: allPartners.map { ($0.id, $0) })
            
            // Group partners by encounter
            var partnersByEncounter: [UUID: [SQLPartner]] = [:]
            for junction in partnerJunctions {
                if let partner = partnersByID[junction.partnerId] {
                    partnersByEncounter[junction.encounterId, default: []].append(partner)
                }
            }
            
            // 3. Batch load ALL activities (NEW: UUID-based)
            let allActivities = try EncounterActivity
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            // Get all unique activity type IDs
            let allActivityTypeIDs = Set(allActivities.map { $0.activityTypeId })
            
            // Batch load activity type entities
            let activityTypeEntities = try SQLActivityTypeEntity
                .where { allActivityTypeIDs.contains($0.id) }
                .fetchAll(db)
            
            let activityTypesByID = Dictionary(uniqueKeysWithValues: activityTypeEntities.map { ($0.id, $0) })
            
            // Group by encounter
            var activityEntitiesByEncounter: [UUID: [SQLActivityTypeEntity]] = [:]
            for activity in allActivities {
                if let entity = activityTypesByID[activity.activityTypeId] {
                    activityEntitiesByEncounter[activity.encounterId, default: []].append(entity)
                }
            }
            
            // 4. Batch load ALL protection methods (NEW: UUID-based)
            let allProtectionMethods = try EncounterProtectionMethod
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            // Get all unique protection method IDs
            let allProtectionMethodIDs = Set(allProtectionMethods.map { $0.protectionMethodId })
            
            // Batch load protection method entities
            let protectionMethodEntities = try SQLProtectionMethodEntity
                .where { allProtectionMethodIDs.contains($0.id) }
                .fetchAll(db)
            
            let protectionMethodsByID = Dictionary(uniqueKeysWithValues: protectionMethodEntities.map { ($0.id, $0) })
            
            // Group by encounter
            var protectionEntitiesByEncounter: [UUID: [SQLProtectionMethodEntity]] = [:]
            for protection in allProtectionMethods {
                if let entity = protectionMethodsByID[protection.protectionMethodId] {
                    protectionEntitiesByEncounter[protection.encounterId, default: []].append(entity)
                }
            }

            // 5. Batch load ALL position types referenced by encounterPartner rows
            let allPositionTypeIDs = Set(partnerJunctions.compactMap { $0.positionTypeId })
            var positionTypesByID: [UUID: SQLPositionType] = [:]
            if !allPositionTypeIDs.isEmpty {
                let positionTypes = try SQLPositionType
                    .where { allPositionTypeIDs.contains($0.id) }
                    .fetchAll(db)
                positionTypesByID = Dictionary(uniqueKeysWithValues: positionTypes.map { ($0.id, $0) })
            }

            // Also load position types for encounter.positionTypeId (my positions)
            let myPositionTypeIDs = Set(encounters.compactMap { $0.positionTypeId })
            var myPositionTypesByID: [UUID: SQLPositionType] = [:]
            if !myPositionTypeIDs.isEmpty {
                let myPositionTypes = try SQLPositionType
                    .where { myPositionTypeIDs.contains($0.id) }
                    .fetchAll(db)
                for pt in myPositionTypes { myPositionTypesByID[pt.id] = pt }
            }

            // Build partnerPositions per encounter: [encounterId: [partnerId: SQLPositionType]]
            var partnerPositionsByEncounter: [UUID: [UUID: SQLPositionType]] = [:]
            for junction in partnerJunctions {
                guard let positionId = junction.positionTypeId,
                      let position = positionTypesByID[positionId] else { continue }
                partnerPositionsByEncounter[junction.encounterId, default: [:]][junction.partnerId] = position
            }
            
            logger.info("Fetched \(encounters.count) encounters with \(allPartners.count) partners, \(allActivities.count) activities, \(allProtectionMethods.count) protection methods")
            
            // 6. Combine everything
            return encounters.map { encounter in
                EncounterWithRelationships(
                    encounter: encounter,
                    partners: partnersByEncounter[encounter.id] ?? [],
                    activityEntities: activityEntitiesByEncounter[encounter.id] ?? [],
                    protectionEntities: protectionEntitiesByEncounter[encounter.id] ?? [],
                    partnerPositions: partnerPositionsByEncounter[encounter.id] ?? [:],
                    myPosition: encounter.positionTypeId.flatMap { myPositionTypesByID[$0] }
                )
            }
        }
    }
    
    /// Fetch encounter by ID
    func fetchByID(_ id: UUID) throws -> SQLEncounter? {
        try database.read { db in
            try SQLEncounter.find(id).fetchOne(db)
        }
    }
    
    /// Fetch encounters for a specific year (nil = all years)
    func fetchByYear(_ year: Int?) throws -> [SQLEncounter] {
        guard let year = year else {
            return try fetchAll()
        }
        
        return try database.read { db in
            let allEncounters = try SQLEncounter
                .order { $0.date.desc() }
                .fetchAll(db)
            
            let calendar = Calendar.current
            return allEncounters.filter { encounter in
                guard let date = encounter.date else { return false }
                return calendar.component(.year, from: date) == year
            }
        }
    }
    
    // MARK: - Update
    
    /// Update an encounter and optionally its relationships
    func update(
        _ encounter: SQLEncounter,
        partnerIDs: [UUID]? = nil,
        partnerPositionTypeIDs: [UUID: UUID?]? = nil,
        myPositionTypeId: UUID?? = nil,
        activityTypeIDs: [UUID]? = nil,
        protectionMethodIDs: [UUID]? = nil
    ) throws {
        try database.write { db in
            let oldPartnerIDs = try SQLEncounterPartner
                .where { $0.encounterId.eq(encounter.id) }
                .fetchAll(db)
                .map { $0.partnerId }

            // Apply myPositionTypeId if provided (double-optional: nil = don't touch)
            var updatedEncounter = encounter
            if let newMyPosition = myPositionTypeId {
                updatedEncounter.positionTypeId = newMyPosition
            }
            try SQLEncounter.update(updatedEncounter).execute(db)

            if let newPartnerIDs = partnerIDs {
                // Delete existing junction rows
                try SQLEncounterPartner
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)

                // Re-insert with positions
                let positions = partnerPositionTypeIDs ?? [:]
                for partnerID in newPartnerIDs {
                    let positionId = positions[partnerID] ?? nil
                    let junction = SQLEncounterPartner(
                        id: UUID(),
                        encounterId: encounter.id,
                        partnerId: partnerID,
                        positionTypeId: positionId
                    )
                    try SQLEncounterPartner.insert { junction }.execute(db)
                }

                let allAffectedPartnerIDs = Set(oldPartnerIDs + newPartnerIDs)
                for partnerID in allAffectedPartnerIDs {
                    try recalculateLastEncounterDate(for: partnerID, db: db)
                }
            } else if let encounterDate = updatedEncounter.date {
                for partnerID in oldPartnerIDs {
                    guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else { continue }
                    if partner.lastEncounterDate == nil || partner.lastEncounterDate! < encounterDate {
                        partner.lastEncounterDate = encounterDate
                        try SQLPartner.update(partner).execute(db)
                    }
                }
            }

            if let newActivityTypeIDs = activityTypeIDs {
                try EncounterActivity.where { $0.encounterId.eq(encounter.id) }.delete().execute(db)
                try EncounterActivity.insert {
                    newActivityTypeIDs.map { EncounterActivity(id: UUID(), encounterId: encounter.id, activityTypeId: $0) }
                }.execute(db)
            }

            if let newProtectionMethodIDs = protectionMethodIDs {
                try EncounterProtectionMethod.where { $0.encounterId.eq(encounter.id) }.delete().execute(db)
                try EncounterProtectionMethod.insert {
                    newProtectionMethodIDs.map { EncounterProtectionMethod(id: UUID(), encounterId: encounter.id, protectionMethodId: $0) }
                }.execute(db)
            }
        }
    }
    
    // MARK: - Delete
    
    /// Delete an encounter and all related data
    func delete(_ encounterID: UUID) throws {
        try database.write { db in
            // Get partners before deleting (to recalculate their lastEncounterDate)
            let partnerIDs = try SQLEncounterPartner
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
                .map { $0.partnerId }
            
            // Delete junction table entries
            try SQLEncounterPartner
                .where { $0.encounterId.eq(encounterID) }
                .delete()
                .execute(db)
            
            // Delete activities
            try EncounterActivity
                .where { $0.encounterId.eq(encounterID) }
                .delete()
                .execute(db)
            
            // Delete protection methods
            try EncounterProtectionMethod
                .where { $0.encounterId.eq(encounterID) }
                .delete()
                .execute(db)
            
            // Delete encounter
            try SQLEncounter
                .where { $0.id.eq(encounterID) }
                .delete()
                .execute(db)
            
            // Recalculate lastEncounterDate for all affected partners
            for partnerID in partnerIDs {
                try recalculateLastEncounterDate(for: partnerID, db: db)
            }
            logger.info("Deleted encounter: \(encounterID)")
        }
    }
    
    /// Delete all encounters
    func deleteAll() throws {
        try database.write { db in
            // Delete all junction table entries
            try SQLEncounterPartner.delete().execute(db)
            
            // Delete all activities
            try EncounterActivity.delete().execute(db)
            
            // Delete all protection methods
            try EncounterProtectionMethod.delete().execute(db)
            
            // Delete all encounters
            try SQLEncounter.delete().execute(db)
            logger.info("Deleted all encounters")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Recalculate and update a partner's lastEncounterDate based on their encounters
    /// Called after deleting an encounter or changing partner associations
    private func recalculateLastEncounterDate(for partnerID: UUID, db: Database) throws {
        // Find the most recent encounter date for this partner
        let maxDate = try Date.fetchOne(
            db,
            sql: """
                SELECT MAX(e."date")
                FROM "encounter" e
                INNER JOIN "encounterPartner" ep ON e."id" = ep."encounterId"
                WHERE ep."partnerId" = ?
            """,
            arguments: [partnerID.uuidString]
        )
        
        // Update the partner's lastEncounterDate directly in this transaction
        if let date = maxDate {
            guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else {
                return
            }
            partner.lastEncounterDate = date
            try SQLPartner.update(partner).execute(db)
        } else {
            // No encounters found, clear the date
            try db.execute(
                sql: "UPDATE \"partner\" SET \"lastEncounterDate\" = NULL WHERE \"id\" = ?",
                arguments: [partnerID.uuidString]
            )
        }
    }
    
    // MARK: - Relationships
    
    /// Get partners for a specific encounter
    func fetchPartners(for encounterID: UUID) throws -> [SQLPartner] {
        try database.read { db in
            try SQLPartner
                .join(SQLEncounterPartner.all) { partner, junction in
                    partner.id.eq(junction.partnerId)
                }
                .where { _, junction in
                    junction.encounterId.eq(encounterID)
                }
                .select { partner, _ in partner }
                .fetchAll(db)
        }
    }
    
    /// Get activity type entities for a specific encounter (NEW: UUID-based)
    func fetchActivityEntities(for encounterID: UUID) throws -> [SQLActivityTypeEntity] {
        try database.read { db in
            // Fetch activity junction records
            let activityJunctions = try EncounterActivity
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
            
            // Get unique activity type IDs
            let activityTypeIDs = activityJunctions.compactMap { $0.activityTypeId }
            
            guard !activityTypeIDs.isEmpty else { return [] }
            
            // Fetch activity type entities
            return try SQLActivityTypeEntity
                .where { activityTypeIDs.contains($0.id) }
                .fetchAll(db)
        }
    }
    
    /// Get protection method entities for a specific encounter (NEW: UUID-based)
    func fetchProtectionMethodEntities(for encounterID: UUID) throws -> [SQLProtectionMethodEntity] {
        try database.read { db in
            // Fetch protection method junction records
            let protectionJunctions = try EncounterProtectionMethod
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
            
            // Get unique protection method IDs
            let protectionMethodIDs = protectionJunctions.compactMap { $0.protectionMethodId }
            
            guard !protectionMethodIDs.isEmpty else { return [] }
            
            // Fetch protection method entities
            return try SQLProtectionMethodEntity
                .where { protectionMethodIDs.contains($0.id) }
                .fetchAll(db)
        }
    }

    /// Fetch raw encounterPartner junction rows for a specific encounter (for loading positions in form/detail views)
    func fetchEncounterPartnerJunctions(for encounterID: UUID) throws -> [SQLEncounterPartner] {
        try database.read { db in
            try SQLEncounterPartner
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
        }
    }

}

// MARK: - Dependency Key

import Dependencies

extension EncounterService: DependencyKey {
    nonisolated static var liveValue: EncounterService { EncounterService() }
}

extension DependencyValues {
    var encounterService: EncounterService {
        get { self[EncounterService.self] }
        set { self[EncounterService.self] = newValue }
    }
}
