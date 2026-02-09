//
//  PartnerService.swift
//  Fuckify
//
//  Database service for Partner CRUD operations using SQLiteData
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

/// Service layer for Partner database operations
/// Uses SQLiteData's query builder and GRDB database connection
struct PartnerService {
    @Dependency(\.defaultDatabase) var database
    
    // Synthesized memberwise init is nonisolated
    nonisolated init() {}
    
    // MARK: - Create
    
    /// Insert a new partner and return it
    func create(_ partnerDraft: SQLPartner.Draft) throws -> SQLPartner {
        try database.write { db in
            // Create a full SQLPartner with a new UUID
            let partner = SQLPartner(
                id: UUID(),
                name: partnerDraft.name,
                notes: partnerDraft.notes,
                phoneNumber: partnerDraft.phoneNumber,
                isOnPrep: partnerDraft.isOnPrep,
                relationshipType: partnerDraft.relationshipType,
                dateMet: partnerDraft.dateMet,
                avatarColor: partnerDraft.avatarColor,
                dateAdded: partnerDraft.dateAdded,
                lastEncounterDate: partnerDraft.lastEncounterDate,
                isPinned: partnerDraft.isPinned
            )
            
            try SQLPartner.insert { partner }
                .execute(db)
            
            return partner
        }
    }
    
    // MARK: - Read
    
    /// Fetch all partners sorted by name
    func fetchAll() throws -> [SQLPartner] {
        try database.read { db in
            try SQLPartner
                .order(by: \.name)
                .fetchAll(db)
        }
    }
    
    /// Fetch partner by ID
    func fetchByID(_ id: UUID) throws -> SQLPartner? {
        try database.read { db in
            try SQLPartner.find(id).fetchOne(db)
        }
    }
    
    /// Fetch all pinned partners
    func fetchPinned() throws -> [SQLPartner] {
        try database.read { db in
            try SQLPartner
                .where { $0.isPinned }
                .order(by: \.name)
                .fetchAll(db)
        }
    }
    
    /// Search partners by name
    func search(name: String) throws -> [SQLPartner] {
        guard !name.isEmpty else {
            return try fetchAll()
        }
        
        return try database.read { db in
            try SQLPartner
                .where { partner in
                    partner.name.like("%\(name)%")
                }
                .order(by: \.name)
                .fetchAll(db)
        }
    }
    
    // MARK: - Update
    
    /// Update a partner
    func update(_ partner: SQLPartner) throws {
        try database.write { db in
            try SQLPartner
                .update(partner)
                .execute(db)
        }
    }
    
    /// Toggle pin status for a partner
    func togglePin(for partnerID: UUID) throws {
        try database.write { db in
            guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else {
                return
            }
            partner.isPinned.toggle()
            try SQLPartner.update(partner).execute(db)
        }
    }
    
    /// Update last encounter date for a partner
    func updateLastEncounterDate(_ partnerID: UUID, date: Date) throws {
        try database.write { db in
            guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else {
                return
            }
            
            // Only update if this date is newer
            if partner.lastEncounterDate == nil || partner.lastEncounterDate! < date {
                partner.lastEncounterDate = date
                try SQLPartner.update(partner).execute(db)
            }
        }
    }
    
    // MARK: - Delete
    
    /// Delete a partner and all related junction table entries
    func delete(_ partnerID: UUID) throws {
        try database.write { db in
            // Delete from junction table
            try SQLEncounterPartner
                .where { $0.partnerId.eq(partnerID) }
                .delete()
                .execute(db)
            
            // Delete the partner
            try SQLPartner
                .where { $0.id.eq(partnerID) }
                .delete()
                .execute(db)
        }
    }
    
    /// Delete all partners
    func deleteAll() throws {
        try database.write { db in
            // Delete all junction table entries
            try SQLEncounterPartner
                .delete()
                .execute(db)
            
            // Delete all partners
            try SQLPartner
                .delete()
                .execute(db)
        }
    }
    
    // MARK: - Relationships
    
    /// Get all encounters for a specific partner
    func fetchEncounters(for partnerID: UUID) throws -> [SQLEncounter] {
        try database.read { db in
            // Join through junction table
            // Note: order must come before join when using keypaths
            try SQLEncounter
                .order { $0.date.desc() }
                .join(SQLEncounterPartner.all) { encounter, junction in
                    encounter.id.eq(junction.encounterId)
                }
                .where { _, junction in
                    junction.partnerId.eq(partnerID)
                }
                .select { encounter, _ in encounter }
                .fetchAll(db)
        }
    }
}

// MARK: - Dependency Key

import Dependencies

extension PartnerService: DependencyKey {
    nonisolated static var liveValue: PartnerService { PartnerService() }
}

extension DependencyValues {
    var partnerService: PartnerService {
        get { self[PartnerService.self] }
        set { self[PartnerService.self] = newValue }
    }
}
