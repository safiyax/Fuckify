//
//  AddForeignKeyIndexes.swift
//  Fuckify
//
//  Migration to add indexes on foreign key columns for performance
//  Impact: 10-100x faster joins with large datasets
//

import Foundation
import SQLiteData

struct AddForeignKeyIndexes {
    nonisolated static func migrate(_ db: Database) throws {
        // MARK: - Encounter-Partner Junction Table Indexes
        
        // Index on encounterId for fast lookups: "get all partners for this encounter"
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterPartner_encounterId"
            ON "encounterPartner"("encounterId")
        """)
        .execute(db)
        
        // Index on partnerId for fast lookups: "get all encounters for this partner"
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterPartner_partnerId"
            ON "encounterPartner"("partnerId")
        """)
        .execute(db)
        
        // MARK: - Encounter-Activity Junction Table Indexes
        
        // Index on encounterId for fast lookups: "get all activities for this encounter"
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterActivity_encounterId"
            ON "encounterActivity"("encounterId")
        """)
        .execute(db)
        
        // Index on activityTypeId for fast lookups: "get all encounters with this activity"
        // Note: This column may be NULL for old records still using enum-based activityType
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterActivity_activityTypeId"
            ON "encounterActivity"("activityTypeId")
            WHERE "activityTypeId" IS NOT NULL
        """)
        .execute(db)
        
        // MARK: - Encounter-Protection Junction Table Indexes
        
        // Index on encounterId for fast lookups: "get all protection methods for this encounter"
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterProtectionMethod_encounterId"
            ON "encounterProtectionMethod"("encounterId")
        """)
        .execute(db)
        
        // Index on protectionMethodId for fast lookups: "get all encounters with this protection"
        // Note: This column may be NULL for old records still using enum-based protectionMethod
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounterProtectionMethod_protectionMethodId"
            ON "encounterProtectionMethod"("protectionMethodId")
            WHERE "protectionMethodId" IS NOT NULL
        """)
        .execute(db)
        
        // MARK: - Partner Table Indexes
        
        // Composite index for partner list sorting (pinned first, then by last encounter date)
        // This optimizes the common query: "show pinned partners first, sorted by recent activity"
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_partner_isPinned_lastEncounterDate"
            ON "partner"("isPinned" DESC, "lastEncounterDate" DESC)
        """)
        .execute(db)
        
        // MARK: - Encounter Table Indexes
        
        // Index on date for fast chronological queries and sorting
        // This optimizes calendar view and statistics filtering by date
        try #sql("""
            CREATE INDEX IF NOT EXISTS "idx_encounter_date"
            ON "encounter"("date" DESC)
        """)
        .execute(db)
    }
}
