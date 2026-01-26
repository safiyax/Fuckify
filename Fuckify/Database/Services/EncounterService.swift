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
    let activities: [SQLActivityType]
    let protectionMethods: [SQLProtectionMethod]
    
    var id: UUID { encounter.id }
}

/// Service layer for Encounter database operations
/// Uses SQLiteData's query builder and GRDB database connection
struct EncounterService {
    @Dependency(\.defaultDatabase) var database
    
    // MARK: - Create
    
    /// Create an encounter with partners, activities, and protection methods
    /// All operations in a single transaction
    func create(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        activities: [SQLActivityType],
        protectionMethods: [SQLProtectionMethod]
    ) throws -> UUID {
        try database.write { db in
            // Create a full SQLEncounter with a new UUID
            let encounterID = UUID()
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
            
            // Link activities
            try EncounterActivity.insert {
                activities.map { activity in
                    EncounterActivity.Draft(
                        id: UUID(),
                        encounterId: encounterID,
                        activityType: activity
                    )
                }
            }
            .execute(db)
            
            // Link protection methods
            try EncounterProtectionMethod.insert {
                protectionMethods.map { method in
                    EncounterProtectionMethod.Draft(
                        id: UUID(),
                        encounterId: encounterID,
                        protectionMethod: method
                    )
                }
            }
            .execute(db)
            
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
            
            // 3. Batch load ALL activities
            let allActivities = try EncounterActivity
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            var activitiesByEncounter: [UUID: [SQLActivityType]] = [:]
            for activity in allActivities {
                activitiesByEncounter[activity.encounterId, default: []].append(activity.activityType)
            }
            
            // 4. Batch load ALL protection methods
            let allProtectionMethods = try EncounterProtectionMethod
                .where { encounterIDs.contains($0.encounterId) }
                .fetchAll(db)
            
            var protectionByEncounter: [UUID: [SQLProtectionMethod]] = [:]
            for protection in allProtectionMethods {
                protectionByEncounter[protection.encounterId, default: []].append(protection.protectionMethod)
            }
            
            // 5. Combine everything
            return encounters.map { encounter in
                EncounterWithRelationships(
                    encounter: encounter,
                    partners: partnersByEncounter[encounter.id] ?? [],
                    activities: activitiesByEncounter[encounter.id] ?? [],
                    protectionMethods: protectionByEncounter[encounter.id] ?? []
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
        activities: [SQLActivityType]? = nil,
        protectionMethods: [SQLProtectionMethod]? = nil
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
            
            // Update activities if provided
            if let newActivities = activities {
                try EncounterActivity
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)
                
                try EncounterActivity.insert {
                    newActivities.map { activity in
                        EncounterActivity.Draft(
                            id: UUID(),
                            encounterId: encounter.id,
                            activityType: activity
                        )
                    }
                }
                .execute(db)
            }
            
            // Update protection methods if provided
            if let newMethods = protectionMethods {
                try EncounterProtectionMethod
                    .where { $0.encounterId.eq(encounter.id) }
                    .delete()
                    .execute(db)
                
                try EncounterProtectionMethod.insert {
                    newMethods.map { method in
                        EncounterProtectionMethod.Draft(
                            id: UUID(),
                            encounterId: encounter.id,
                            protectionMethod: method
                        )
                    }
                }
                .execute(db)
            }
        }
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
    
    /// Get activities for a specific encounter
    func fetchActivities(for encounterID: UUID) throws -> [SQLActivityType] {
        try database.read { db in
            try EncounterActivity
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
                .map(\.activityType)
        }
    }
    
    /// Get protection methods for a specific encounter
    func fetchProtectionMethods(for encounterID: UUID) throws -> [SQLProtectionMethod] {
        try database.read { db in
            try EncounterProtectionMethod
                .where { $0.encounterId.eq(encounterID) }
                .fetchAll(db)
                .map(\.protectionMethod)
        }
    }
}
