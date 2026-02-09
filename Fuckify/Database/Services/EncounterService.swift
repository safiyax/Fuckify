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

/// Complete encounter data with all relationships loaded
/// Used to avoid N+1 query problems
struct EncounterWithRelationships: Identifiable {
    let encounter: SQLEncounter
    let partners: [SQLPartner]
    let activities: [SQLActivityType]              // Deprecated: use activityEntities
    let protectionMethods: [SQLProtectionMethod]   // Deprecated: use protectionEntities
    let activityEntities: [SQLActivityTypeEntity]?
    let protectionEntities: [SQLProtectionMethodEntity]?
    
    var id: UUID { encounter.id }
    
    init(
        encounter: SQLEncounter,
        partners: [SQLPartner],
        activities: [SQLActivityType] = [],
        protectionMethods: [SQLProtectionMethod] = [],
        activityEntities: [SQLActivityTypeEntity]? = nil,
        protectionEntities: [SQLProtectionMethodEntity]? = nil
    ) {
        self.encounter = encounter
        self.partners = partners
        self.activities = activities
        self.protectionMethods = protectionMethods
        self.activityEntities = activityEntities
        self.protectionEntities = protectionEntities
    }
}

/// Service layer for Encounter database operations
/// Uses SQLiteData's query builder and GRDB database connection
struct EncounterService {
    @Dependency(\.defaultDatabase) var database
    
    // MARK: - Create
    
    /// Create an encounter with partners, activities, and protection methods (NEW: UUID-based)
    /// All operations in a single transaction
    func create(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        activityTypeIDs: [UUID],
        protectionMethodIDs: [UUID]
    ) throws -> UUID {
        try database.write { db in
            // Use the ID from the draft if provided, otherwise generate a new one
            let encounterID = encounterDraft.id ?? UUID()
            let encounter = SQLEncounter(
                id: encounterID,
                date: encounterDraft.date,
                duration: encounterDraft.duration,
                location: encounterDraft.location,
                notes: encounterDraft.notes,
                rating: encounterDraft.rating,
                reachedOrgasm: encounterDraft.reachedOrgasm,
                dateAdded: encounterDraft.dateAdded
            )
            
            // Insert encounter
            try SQLEncounter.insert { encounter }
                .execute(db)
            
            // Link partners
            try SQLEncounterPartner.insert {
                partnerIDs.map { partnerID in
                    SQLEncounterPartner.Draft(
                        id: UUID(),
                        encounterId: encounterID,
                        partnerId: partnerID
                    )
                }
            }
            .execute(db)
            
            // Link activities using UUIDs
            try EncounterActivity.insert {
                activityTypeIDs.map { activityTypeID in
                    EncounterActivity.Draft(
                        id: UUID(),
                        encounterId: encounterID,
                        activityTypeId: activityTypeID,
                        activityType: nil  // New approach: use UUID
                    )
                }
            }
            .execute(db)
            
            // Link protection methods using UUIDs
            try EncounterProtectionMethod.insert {
                protectionMethodIDs.map { methodID in
                    EncounterProtectionMethod.Draft(
                        id: UUID(),
                        encounterId: encounterID,
                        protectionMethodId: methodID,
                        protectionMethod: nil  // New approach: use UUID
                    )
                }
            }
            .execute(db)
            
            return encounterID
        }
    }
    
    /// Create an encounter with partners, activities, and protection methods (DEPRECATED: enum-based)
    /// All operations in a single transaction
    @available(*, deprecated, message: "Use create(_:partnerIDs:activityTypeIDs:protectionMethodIDs:) instead")
    func createLegacy(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        activities: [SQLActivityType],
        protectionMethods: [SQLProtectionMethod]
    ) throws -> UUID {
        // Convert enums to UUIDs and use new method
        let activityTypeIDs = activities.map { $0.predefinedUUID }
        let protectionMethodIDs = protectionMethods.map { $0.predefinedUUID }
        return try create(
            encounterDraft,
            partnerIDs: partnerIDs,
            activityTypeIDs: activityTypeIDs,
            protectionMethodIDs: protectionMethodIDs
        )
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
            let allActivityTypeIDs = Set(allActivities.compactMap { $0.activityTypeId })
            
            // Batch load activity type entities
            let activityTypeEntities = try SQLActivityTypeEntity
                .where { allActivityTypeIDs.contains($0.id) }
                .fetchAll(db)
            
            let activityTypesByID = Dictionary(uniqueKeysWithValues: activityTypeEntities.map { ($0.id, $0) })
            
            // Group by encounter
            var activityEntitiesByEncounter: [UUID: [SQLActivityTypeEntity]] = [:]
            for activity in allActivities {
                if let activityTypeID = activity.activityTypeId,
                   let entity = activityTypesByID[activityTypeID] {
                    activityEntitiesByEncounter[activity.encounterId, default: []].append(entity)
                }
            }
            
            // 4. Batch load ALL protection methods (NEW: UUID-based)
            let allProtectionMethods = try EncounterProtectionMethod
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            // Get all unique protection method IDs
            let allProtectionMethodIDs = Set(allProtectionMethods.compactMap { $0.protectionMethodId })
            
            // Batch load protection method entities
            let protectionMethodEntities = try SQLProtectionMethodEntity
                .where { allProtectionMethodIDs.contains($0.id) }
                .fetchAll(db)
            
            let protectionMethodsByID = Dictionary(uniqueKeysWithValues: protectionMethodEntities.map { ($0.id, $0) })
            
            // Group by encounter
            var protectionEntitiesByEncounter: [UUID: [SQLProtectionMethodEntity]] = [:]
            for protection in allProtectionMethods {
                if let protectionMethodID = protection.protectionMethodId,
                   let entity = protectionMethodsByID[protectionMethodID] {
                    protectionEntitiesByEncounter[protection.encounterId, default: []].append(entity)
                }
            }
            
            // 5. Combine everything
            return encounters.map { encounter in
                EncounterWithRelationships(
                    encounter: encounter,
                    partners: partnersByEncounter[encounter.id] ?? [],
                    activities: [],  // Deprecated
                    protectionMethods: [],  // Deprecated
                    activityEntities: activityEntitiesByEncounter[encounter.id],
                    protectionEntities: protectionEntitiesByEncounter[encounter.id]
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
    
    /// Update an encounter and optionally its relationships (NEW: UUID-based)
    func update(
        _ encounter: SQLEncounter,
        partnerIDs: [UUID]? = nil,
        activityTypeIDs: [UUID]? = nil,
        protectionMethodIDs: [UUID]? = nil
    ) throws {
        try database.write { db in
            // Update encounter
            try SQLEncounter.update(encounter).execute(db)
            
            // Update partners if provided
            if let newPartnerIDs = partnerIDs {
                // Delete existing links
                try SQLEncounterPartner
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)
                
                // Insert new links
                try SQLEncounterPartner.insert {
                    newPartnerIDs.map { partnerID in
                        SQLEncounterPartner.Draft(
                            id: UUID(),
                            encounterId: encounter.id,
                            partnerId: partnerID
                        )
                    }
                }
                .execute(db)
            }
            
            // Update activities if provided (NEW: UUID-based)
            if let newActivityTypeIDs = activityTypeIDs {
                try EncounterActivity
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)
                
                try EncounterActivity.insert {
                    newActivityTypeIDs.map { activityTypeID in
                        EncounterActivity.Draft(
                            id: UUID(),
                            encounterId: encounter.id,
                            activityTypeId: activityTypeID,
                            activityType: nil
                        )
                    }
                }
                .execute(db)
            }
            
            // Update protection methods if provided (NEW: UUID-based)
            if let newProtectionMethodIDs = protectionMethodIDs {
                try EncounterProtectionMethod
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)
                
                try EncounterProtectionMethod.insert {
                    newProtectionMethodIDs.map { methodID in
                        EncounterProtectionMethod.Draft(
                            id: UUID(),
                            encounterId: encounter.id,
                            protectionMethodId: methodID,
                            protectionMethod: nil
                        )
                    }
                }
                .execute(db)
            }
        }
    }
    
    /// Update an encounter and optionally its relationships (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use update(_:partnerIDs:activityTypeIDs:protectionMethodIDs:) instead")
    func updateLegacy(
        _ encounter: SQLEncounter,
        partnerIDs: [UUID]? = nil,
        activities: [SQLActivityType]? = nil,
        protectionMethods: [SQLProtectionMethod]? = nil
    ) throws {
        // Convert enums to UUIDs and use new method
        let activityTypeIDs = activities?.map { $0.predefinedUUID }
        let protectionMethodIDs = protectionMethods?.map { $0.predefinedUUID }
        try update(
            encounter,
            partnerIDs: partnerIDs,
            activityTypeIDs: activityTypeIDs,
            protectionMethodIDs: protectionMethodIDs
        )
    }
    
    // MARK: - Delete
    
    /// Delete an encounter and all related data
    func delete(_ encounterID: UUID) throws {
        try database.write { db in
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
    
    /// Get activities for a specific encounter (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use fetchActivityEntities(for:) instead")
    func fetchActivities(for encounterID: UUID) throws -> [SQLActivityType] {
        try database.read { db in
            try EncounterActivity
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
                .compactMap { $0.activityType }
        }
    }
    
    /// Get protection methods for a specific encounter (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use fetchProtectionMethodEntities(for:) instead")
    func fetchProtectionMethods(for encounterID: UUID) throws -> [SQLProtectionMethod] {
        try database.read { db in
            try EncounterProtectionMethod
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
                .compactMap { $0.protectionMethod }
        }
    }
}

// MARK: - Dependency Key

import Dependencies

extension EncounterService: DependencyKey {
    static var liveValue: EncounterService { EncounterService() }
}

extension DependencyValues {
    var encounterService: EncounterService {
        get { self[EncounterService.self] }
        set { self[EncounterService.self] = newValue }
    }
}
