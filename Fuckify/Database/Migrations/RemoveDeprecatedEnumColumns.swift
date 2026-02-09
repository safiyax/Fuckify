//
//  RemoveDeprecatedEnumColumns.swift
//  Fuckify
//
//  Migration to remove deprecated enum-based columns from junction tables
//  Completes the transition to UUID-based activity/protection method references
//

import Foundation
import SQLiteData

struct RemoveDeprecatedEnumColumns {
    nonisolated static func migrate(_ db: Database) throws {
        // IMPORTANT: This migration assumes all data has been migrated to UUID columns
        // If there are any NULL values in activityTypeId or protectionMethodId,
        // this migration will fail intentionally to prevent data loss
        
        // 1. Verify no NULL values in new columns (safety check)
        let activityNullCount = try Int64.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM encounterActivity WHERE activityTypeId IS NULL"
        ) ?? 0
        
        let protectionNullCount = try Int64.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM encounterProtectionMethod WHERE protectionMethodId IS NULL"
        ) ?? 0
        
        guard activityNullCount == 0 && protectionNullCount == 0 else {
            throw DatabaseError.migrationFailed(
                "Cannot remove deprecated columns: found \(activityNullCount) NULL activityTypeId and \(protectionNullCount) NULL protectionMethodId values. Run data migration first."
            )
        }
        
        // 2. Create new encounterActivity table without activityType column
        try #sql("""
            CREATE TABLE "encounterActivity_new"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL,
                "activityTypeId" TEXT NOT NULL,
                FOREIGN KEY ("encounterId") REFERENCES "encounter"("id") ON DELETE CASCADE,
                FOREIGN KEY ("activityTypeId") REFERENCES "activityType"("id") ON DELETE CASCADE
            ) STRICT
        """)
        .execute(db)
        
        // 3. Copy data to new table (only UUID column)
        try #sql("""
            INSERT INTO "encounterActivity_new" ("id", "encounterId", "activityTypeId")
            SELECT "id", "encounterId", "activityTypeId"
            FROM "encounterActivity"
        """)
        .execute(db)
        
        // 4. Drop old table and rename new table
        try #sql("DROP TABLE \"encounterActivity\"").execute(db)
        try #sql("ALTER TABLE \"encounterActivity_new\" RENAME TO \"encounterActivity\"").execute(db)
        
        // 5. Create indexes on new table
        try #sql("""
            CREATE INDEX "idx_encounterActivity_encounterId" 
            ON "encounterActivity"("encounterId")
        """)
        .execute(db)
        
        try #sql("""
            CREATE INDEX "idx_encounterActivity_activityTypeId" 
            ON "encounterActivity"("activityTypeId")
        """)
        .execute(db)
        
        // 6. Create new encounterProtectionMethod table without protectionMethod column
        try #sql("""
            CREATE TABLE "encounterProtectionMethod_new"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL,
                "protectionMethodId" TEXT NOT NULL,
                FOREIGN KEY ("encounterId") REFERENCES "encounter"("id") ON DELETE CASCADE,
                FOREIGN KEY ("protectionMethodId") REFERENCES "protectionMethodType"("id") ON DELETE CASCADE
            ) STRICT
        """)
        .execute(db)
        
        // 7. Copy data to new table (only UUID column)
        try #sql("""
            INSERT INTO "encounterProtectionMethod_new" ("id", "encounterId", "protectionMethodId")
            SELECT "id", "encounterId", "protectionMethodId"
            FROM "encounterProtectionMethod"
        """)
        .execute(db)
        
        // 8. Drop old table and rename new table
        try #sql("DROP TABLE \"encounterProtectionMethod\"").execute(db)
        try #sql("ALTER TABLE \"encounterProtectionMethod_new\" RENAME TO \"encounterProtectionMethod\"").execute(db)
        
        // 9. Create indexes on new table
        try #sql("""
            CREATE INDEX "idx_encounterProtectionMethod_encounterId" 
            ON "encounterProtectionMethod"("encounterId")
        """)
        .execute(db)
        
        try #sql("""
            CREATE INDEX "idx_encounterProtectionMethod_protectionMethodId" 
            ON "encounterProtectionMethod"("protectionMethodId")
        """)
        .execute(db)
    }
}

enum DatabaseError: Error {
    case migrationFailed(String)
}
