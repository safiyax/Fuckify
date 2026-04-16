//
//  AddPositionTypes.swift
//  Fuckify
//
//  Migration 11: Add positionType catalog table and nullable positionTypeId columns
//

import Foundation
import SQLiteData

struct AddPositionTypes {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create positionType catalog table
        try db.execute(sql: """
            CREATE TABLE "positionType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)

        // 2. Seed built-in position types
        // Pass Date() directly — NOT ISO8601 string — so GRDB encodes correctly
        let topId    = "00000000-0000-0000-0000-000000000401"
        let bottomId = "00000000-0000-0000-0000-000000000402"
        let switchId = "00000000-0000-0000-0000-000000000403"
        let now = Date()

        let insertSQL = """
            INSERT INTO "positionType" ("id","name","icon","isBuiltIn","isEnabled","sortOrder","dateAdded")
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        try db.execute(sql: insertSQL, arguments: [topId,    "Top",    "arrow.up.circle.fill",            1, 1, 0, now])
        try db.execute(sql: insertSQL, arguments: [bottomId, "Bottom", "arrow.down.circle.fill",          1, 1, 1, now])
        try db.execute(sql: insertSQL, arguments: [switchId, "Switch", "arrow.up.arrow.down.circle.fill", 1, 1, 2, now])

        // 3. Add nullable positionTypeId to encounter (user's own position)
        try db.execute(sql: """
            ALTER TABLE "encounter" ADD COLUMN "positionTypeId" TEXT
        """)

        // 4. Add nullable positionTypeId to encounterPartner (per-partner position)
        try db.execute(sql: """
            ALTER TABLE "encounterPartner" ADD COLUMN "positionTypeId" TEXT
        """)
    }
}
