//
//  AddPartnerDefaultPosition.swift
//  Fuckify
//
//  Migration 13: Add defaultPositionTypeId column to partner table
//

import Foundation
import SQLiteData

struct AddPartnerDefaultPosition {
    nonisolated static func migrate(_ db: Database) throws {
        try db.execute(sql: """
            ALTER TABLE "partner" ADD COLUMN "defaultPositionTypeId" TEXT
        """)
    }
}
