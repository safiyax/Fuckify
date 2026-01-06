//
//  SwiftDataTransfer.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import Foundation
import SwiftData
import SQLiteData

struct SwiftDataTransfer {
    static func migrate(_ db: Database, modelContext: ModelContext) throws {
        // Fetch all SwiftData partners
        let partnerDescriptor = FetchDescriptor<Partner_SwiftData>(
            sortBy: [SortDescriptor(\.dateAdded)]
        )
        let swiftDataPartners = try modelContext.fetch(partnerDescriptor)
        
        // Fetch all SwiftData encounters
        let encounterDescriptor = FetchDescriptor<Encounter_SwiftData>(
            sortBy: [SortDescriptor(\.date)]
        )
        let swiftDataEncounters = try modelContext.fetch(encounterDescriptor)
        
        // Create ID mapping for partners
        var partnerIdMapping: [PersistentIdentifier: UUID] = [:]
        
        // Migrate partners
        for swiftPartner in swiftDataPartners {
            let newUUID = UUID()
            
            let partner = SQLPartner(
                id: newUUID,
                name: swiftPartner.name,
                notes: swiftPartner.notes,
                phoneNumber: swiftPartner.phoneNumber,
                isOnPrep: swiftPartner.isOnPrep,
                relationshipType: convertRelationshipType(swiftPartner.relationshipType),
                dateMet: swiftPartner.dateMet,
                avatarColor: swiftPartner.avatarColor,
                dateAdded: swiftPartner.dateAdded,
                lastEncounterDate: swiftPartner.lastEncounterDate,
                isPinned: swiftPartner.isPinned
            )
            
            try SQLPartner.insert { partner }.execute(db)
            
            partnerIdMapping[swiftPartner.persistentModelID] = newUUID
        }
        
        // Migrate encounters and relationships
        for swiftEncounter in swiftDataEncounters {
            let newUUID = UUID()
            
            let encounter = SQLEncounter(
                id: newUUID,
                date: swiftEncounter.date,
                duration: swiftEncounter.duration,
                location: swiftEncounter.location,
                notes: swiftEncounter.notes,
                rating: swiftEncounter.rating,
                reachedOrgasm: swiftEncounter.reachedOrgasm,
                dateAdded: swiftEncounter.dateAdded
            )
            
            try SQLEncounter.insert { encounter }.execute(db)
            
            // Create junction table entries for relationships
            if let partners = swiftEncounter.partners {
                for partner in partners {
                    if let partnerUUID = partnerIdMapping[partner.persistentModelID] {
                        let junction = SQLEncounterPartner(
                            id: UUID(),
                            encounterId: newUUID,
                            partnerId: partnerUUID
                        )
                        
                        try SQLEncounterPartner.insert { junction }.execute(db)
                    }
                }
            }
        }
        
        // Update lastEncounterDate for all partners
        try #sql("""
            UPDATE "partner"
            SET "lastEncounterDate" = (
                SELECT MAX(e.date)
                FROM "encounter" e
                JOIN "encounterPartner" ep ON e.id = ep.encounterId
                WHERE ep.partnerId = partner.id
            )
            WHERE EXISTS (
                SELECT 1
                FROM "encounterPartner" ep
                WHERE ep.partnerId = partner.id
            )
        """)
        .execute(db)
    }
    
    /// Converts SwiftData RelationshipType to SQLiteData RelationshipType
    private static func convertRelationshipType(_ swiftDataType: RelationshipType_SwiftData) -> SQLRelationshipType {
        guard let sqlType = SQLRelationshipType(rawValue: swiftDataType.rawValue) else {
            return .casual
        }
        return sqlType
    }
    
    /// Converts SwiftData ActivityType to SQLiteData ActivityType
    private static func convertActivityType(_ swiftDataType: ActivityType_SwiftData) -> SQLActivityType {
        guard let sqlType = SQLActivityType(rawValue: swiftDataType.rawValue) else {
            return .other
        }
        return sqlType
    }
    
    /// Converts SwiftData ProtectionMethod to SQLiteData ProtectionMethod
    private static func convertProtectionMethod(_ swiftDataMethod: ProtectionMethod_SwiftData) -> SQLProtectionMethod {
        guard let sqlMethod = SQLProtectionMethod(rawValue: swiftDataMethod.rawValue) else {
            return .other
        }
        return sqlMethod
    }
}

typealias Partner_SwiftData = Partner
typealias Encounter_SwiftData = Encounter
typealias RelationshipType_SwiftData = RelationshipType
typealias ProtectionMethod_SwiftData = ProtectionMethod
typealias ActivityType_SwiftData = ActivityType
