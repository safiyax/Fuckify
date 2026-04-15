//
//  NormalizeSTITestIds.swift
//  Fuckify
//
//  Migration 10: Lowercase all stiTest and stiTestResultType id/resultTypeId values
//  to match SQLiteData's UUID binding convention (uuid.uuidString.lowercased()).
//

import Foundation
import SQLiteData

struct NormalizeSTITestIds {
    nonisolated static func migrate(_ db: Database) throws {
        // Lowercase all stiTest ids and resultTypeIds
        try db.execute(sql: """
            UPDATE "stiTest"
            SET "id" = LOWER("id"),
                "resultTypeId" = LOWER("resultTypeId")
        """)

        // Lowercase all stiTestResultType ids
        try db.execute(sql: """
            UPDATE "stiTestResultType"
            SET "id" = LOWER("id")
        """)
    }
}
