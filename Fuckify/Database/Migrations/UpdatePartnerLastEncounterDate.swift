//
//  UpdatePartnerLastEncounterDate.swift
//  Fuckify
//
//  Migration to populate partner.lastEncounterDate from existing encounters
//

import Foundation
import SQLiteData

struct UpdatePartnerLastEncounterDate {
    nonisolated static func migrate(_ db: Database) throws {
        // Update each partner's lastEncounterDate to be the date of their most recent encounter
        // Uses a subquery to find the max encounter date for each partner via the junction table
        
        try db.execute(sql: """
            UPDATE "partner"
            SET "lastEncounterDate" = (
                SELECT MAX(e."date")
                FROM "encounter" e
                INNER JOIN "encounterPartner" ep ON e."id" = ep."encounterId"
                WHERE ep."partnerId" = "partner"."id"
            )
            WHERE EXISTS (
                SELECT 1
                FROM "encounterPartner" ep
                WHERE ep."partnerId" = "partner"."id"
            )
        """)
        
        // Clear lastEncounterDate for partners with no encounters
        try db.execute(sql: """
            UPDATE "partner"
            SET "lastEncounterDate" = NULL
            WHERE "id" NOT IN (
                SELECT DISTINCT "partnerId"
                FROM "encounterPartner"
            )
        """)
    }
}
