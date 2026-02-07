//
//  AddCustomizationTables.swift
//  Fuckify
//
//  Migration to add customizable activity types and protection methods
//

import Foundation
import SQLiteData

struct AddCustomizationTables {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create activityType table
        try #sql("""
            CREATE TABLE "activityType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // 2. Create protectionMethodType table
        try #sql("""
            CREATE TABLE "protectionMethodType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // 3. Seed default activity types
        let activityTypes = SQLActivityType.allCases
        for (index, activityType) in activityTypes.enumerated() {
            let entity = activityType.toEntity(sortOrder: index, isEnabled: true)
            try db.execute(
                sql: """
                INSERT INTO "activityType" 
                ("id", "name", "icon", "isBuiltIn", "isEnabled", "sortOrder", "dateAdded")
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [entity.id.uuidString, entity.name, entity.icon, entity.isBuiltIn, entity.isEnabled, entity.sortOrder, entity.dateAdded]
            )
        }
        
        // 4. Seed default protection method types
        let protectionMethods = SQLProtectionMethod.allCases
        for (index, protectionMethod) in protectionMethods.enumerated() {
            let entity = protectionMethod.toEntity(sortOrder: index, isEnabled: true)
            try db.execute(
                sql: """
                INSERT INTO "protectionMethodType" 
                ("id", "name", "icon", "isBuiltIn", "isEnabled", "sortOrder", "dateAdded")
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [entity.id.uuidString, entity.name, entity.icon, entity.isBuiltIn, entity.isEnabled, entity.sortOrder, entity.dateAdded]
            )
        }
        
        // 5. Add new columns to junction tables (nullable for migration)
        try #sql("""
            ALTER TABLE "encounterActivity" 
            ADD COLUMN "activityTypeId" TEXT
        """)
        .execute(db)
        
        try #sql("""
            ALTER TABLE "encounterProtectionMethod" 
            ADD COLUMN "protectionMethodId" TEXT
        """)
        .execute(db)
        
        // 6. Migrate existing data from activityType to activityTypeId
        // For each activity type, update all records that match
        for activityType in activityTypes {
            try db.execute(
                sql: """
                UPDATE "encounterActivity"
                SET "activityTypeId" = ?
                WHERE "activityType" = ?
                """,
                arguments: [activityType.predefinedUUID.uuidString, activityType.rawValue]
            )
        }
        
        // 7. Migrate existing data from protectionMethod to protectionMethodId
        for protectionMethod in protectionMethods {
            try db.execute(
                sql: """
                UPDATE "encounterProtectionMethod"
                SET "protectionMethodId" = ?
                WHERE "protectionMethod" = ?
                """,
                arguments: [protectionMethod.predefinedUUID.uuidString, protectionMethod.rawValue]
            )
        }
        
        // 8. Apply UserSettings preferences to isEnabled column
        // Read enabled activities from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "enabledActivities"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            let enabledActivityTypes = Set(decoded.compactMap { SQLActivityType(rawValue: $0) })
            
            // Update isEnabled for each activity type
            for activityType in activityTypes {
                let isEnabled = enabledActivityTypes.contains(activityType)
                try db.execute(
                    sql: """
                    UPDATE "activityType"
                    SET "isEnabled" = ?
                    WHERE "id" = ?
                    """,
                    arguments: [isEnabled, activityType.predefinedUUID.uuidString]
                )
            }
        }
        
        // Read enabled protection methods from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "enabledProtectionMethods"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            let enabledProtectionMethods = Set(decoded.compactMap { SQLProtectionMethod(rawValue: $0) })
            
            // Update isEnabled for each protection method
            for protectionMethod in protectionMethods {
                let isEnabled = enabledProtectionMethods.contains(protectionMethod)
                try db.execute(
                    sql: """
                    UPDATE "protectionMethodType"
                    SET "isEnabled" = ?
                    WHERE "id" = ?
                    """,
                    arguments: [isEnabled, protectionMethod.predefinedUUID.uuidString]
                )
            }
        }
        
        // Note: We're keeping the old activityType and protectionMethod columns
        // for rollback safety. They can be removed in a future migration after
        // confirming the new system works properly.
    }
}
