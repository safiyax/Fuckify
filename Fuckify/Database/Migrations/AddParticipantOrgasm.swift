//
//  AddParticipantOrgasm.swift
//  Fuckify
//
//  Migration 12: Add hadOrgasm column to encounterPartner table
//

import Foundation
import SQLiteData

struct AddParticipantOrgasm {
    nonisolated static func migrate(_ db: Database) throws {
        // Add hadOrgasm column with default 0 (false) so existing rows are unaffected
        try db.execute(sql: """
            ALTER TABLE "encounterPartner" ADD COLUMN "hadOrgasm" INTEGER NOT NULL DEFAULT 0
        """)
    }
}
