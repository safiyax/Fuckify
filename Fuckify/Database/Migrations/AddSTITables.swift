//
//  AddSTITables.swift
//  Fuckify
//
//  Migration 9: Add STI test tracking tables and migrate existing lastSTITestDate
//

import Foundation
import SQLiteData

struct AddSTITables {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create stiTestResultType table (catalog — mirrors activityType)
        try db.execute(sql: """
            CREATE TABLE "stiTestResultType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)

        // 2. Seed built-in result types
        let negativeId = "00000000-0000-0000-0000-000000000301"
        let positiveId = "00000000-0000-0000-0000-000000000302"
        let pendingId  = "00000000-0000-0000-0000-000000000303"
        let now = ISO8601DateFormatter().string(from: Date())

        try db.execute(sql: """
            INSERT INTO "stiTestResultType" ("id","name","icon","isBuiltIn","isEnabled","sortOrder","dateAdded")
            VALUES
                ('\(negativeId)', 'Negative', 'checkmark.circle.fill',    1, 1, 0, '\(now)'),
                ('\(positiveId)', 'Positive', 'exclamationmark.triangle.fill', 1, 1, 1, '\(now)'),
                ('\(pendingId)',  'Pending',  'clock.fill',               1, 1, 2, '\(now)')
        """)

        // 3. Create stiTest table
        try db.execute(sql: """
            CREATE TABLE "stiTest"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "date" TEXT NOT NULL,
                "resultTypeId" TEXT NOT NULL,
                "notes" TEXT NOT NULL,
                "dateAdded" TEXT NOT NULL,
                FOREIGN KEY ("resultTypeId") REFERENCES "stiTestResultType"("id") ON DELETE RESTRICT
            ) STRICT
        """)

        // 4. Index on resultTypeId for FK performance
        try db.execute(sql: """
            CREATE INDEX "idx_stiTest_resultTypeId" ON "stiTest"("resultTypeId")
        """)

        // 5. Migrate existing lastSTITestDate from UserDefaults → first stiTest record
        if let existingDate = UserDefaults.standard.object(forKey: "userLastSTITestDate") as? Date {
            let dateStr = ISO8601DateFormatter().string(from: existingDate)
            let recordId = UUID().uuidString
            try db.execute(sql: """
                INSERT INTO "stiTest" ("id","date","resultTypeId","notes","dateAdded")
                VALUES ('\(recordId)', '\(dateStr)', '\(negativeId)', '', '\(now)')
            """)
        }

        // 6. Clear migrated UserDefaults keys
        UserDefaults.standard.removeObject(forKey: "userLastSTITestDate")
        UserDefaults.standard.removeObject(forKey: "userIsOnPrep")
    }
}
