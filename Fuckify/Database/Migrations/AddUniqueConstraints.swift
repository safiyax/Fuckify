//
//  AddUniqueConstraints.swift
//  Fuckify
//
//  Migration to add unique constraints to junction tables
//  Prevents duplicate relationships (e.g., same partner added twice to same encounter)
//

import Foundation
import SQLiteData

struct AddUniqueConstraints {
    nonisolated static func migrate(_ db: Database) throws {
        // MARK: - Encounter-Partner Junction Table
        
        // Prevent duplicate partner assignments to same encounter
        // This ensures each partner can only be linked to an encounter once
        try #sql("""
            CREATE UNIQUE INDEX IF NOT EXISTS "idx_encounterPartner_unique"
            ON "encounterPartner"("encounterId", "partnerId")
        """)
        .execute(db)
        
        // MARK: - Encounter-Activity Junction Table
        
        // Prevent duplicate activity assignments to same encounter
        // Note: Only enforces uniqueness where activityTypeId is not NULL
        // (Old records using enum-based activityType are excluded)
        try #sql("""
            CREATE UNIQUE INDEX IF NOT EXISTS "idx_encounterActivity_unique"
            ON "encounterActivity"("encounterId", "activityTypeId")
            WHERE "activityTypeId" IS NOT NULL
        """)
        .execute(db)
        
        // MARK: - Encounter-Protection Junction Table
        
        // Prevent duplicate protection method assignments to same encounter
        // Note: Only enforces uniqueness where protectionMethodId is not NULL
        // (Old records using enum-based protectionMethod are excluded)
        try #sql("""
            CREATE UNIQUE INDEX IF NOT EXISTS "idx_encounterProtectionMethod_unique"
            ON "encounterProtectionMethod"("encounterId", "protectionMethodId")
            WHERE "protectionMethodId" IS NOT NULL
        """)
        .execute(db)
        
        // Note: These unique indexes also improve query performance
        // SQLite can use them to speed up lookups in addition to enforcing uniqueness
    }
}
