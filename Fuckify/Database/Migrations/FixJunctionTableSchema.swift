//
//  FixJunctionTableSchema.swift
//  Fuckify
//
//  Fix junction tables to make old enum columns nullable
//

import Foundation
import SQLiteData

struct FixJunctionTableSchema {
    nonisolated static func migrate(_ db: Database) throws {
        // Fix encounterActivity table - recreate with nullable activityType
        
        // 1. Backup data
        try db.execute(sql: """
            CREATE TEMPORARY TABLE "encounterActivity_backup" AS 
            SELECT * FROM "encounterActivity"
        """)
        
        // 2. Drop old table
        try db.execute(sql: "DROP TABLE \"encounterActivity\"")
        
        // 3. Create new table with both columns nullable
        try #sql("""
            CREATE TABLE "encounterActivity"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL REFERENCES "encounter"("id") ON DELETE CASCADE,
                "activityTypeId" TEXT,
                "activityType" TEXT
            ) STRICT
        """)
        .execute(db)
        
        // 4. Restore data (both old and new columns if they exist)
        try db.execute(sql: """
            INSERT INTO "encounterActivity" ("id", "encounterId", "activityTypeId", "activityType")
            SELECT "id", "encounterId", "activityTypeId", "activityType" 
            FROM "encounterActivity_backup"
        """)
        
        // 5. Drop backup
        try db.execute(sql: "DROP TABLE \"encounterActivity_backup\"")
        
        // Fix encounterProtectionMethod table - recreate with nullable protectionMethod
        
        // 1. Backup data
        try db.execute(sql: """
            CREATE TEMPORARY TABLE "encounterProtectionMethod_backup" AS 
            SELECT * FROM "encounterProtectionMethod"
        """)
        
        // 2. Drop old table
        try db.execute(sql: "DROP TABLE \"encounterProtectionMethod\"")
        
        // 3. Create new table with both columns nullable
        try #sql("""
            CREATE TABLE "encounterProtectionMethod"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL REFERENCES "encounter"("id") ON DELETE CASCADE,
                "protectionMethodId" TEXT,
                "protectionMethod" TEXT
            ) STRICT
        """)
        .execute(db)
        
        // 4. Restore data
        try db.execute(sql: """
            INSERT INTO "encounterProtectionMethod" ("id", "encounterId", "protectionMethodId", "protectionMethod")
            SELECT "id", "encounterId", "protectionMethodId", "protectionMethod" 
            FROM "encounterProtectionMethod_backup"
        """)
        
        // 5. Drop backup
        try db.execute(sql: "DROP TABLE \"encounterProtectionMethod_backup\"")
    }
}
