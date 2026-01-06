//
//  CreateTables.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

struct CreateTables {
    static func migrate(_ db: Database) throws {
        // create partners table
        try #sql("""
            CREATE TABLE "partner"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "notes" TEXT NOT NULL,
                "phoneNumber" TEXT NOT NULL,
                "isOnPrep" INTEGER NOT NULL,
                "relationshipType" TEXT NOT NULL,
                "dateMet" TEXT,
                "avatarColor" TEXT NOT NULL,
                "dateAdded" TEXT NOT NULL,
                "lastEncounterDate" TEXT,
                "isPinned" INTEGER NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // create encounters table
        try #sql("""
            CREATE TABLE "encounter"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "date" TEXT NOT NULL,
                "duration" REAL NOT NULL,
                "location" TEXT NOT NULL,
                "notes" TEXT NOT NULL,
                "rating" INTEGER NOT NULL,
                "reachedOrgasm" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // Create encounter activities table
        try #sql("""
            CREATE TABLE "encounterActivity"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL REFERENCES "encounter"("id") ON DELETE CASCADE,
                "activityType" TEXT NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // Create encounter protection methods table
        try #sql("""
            CREATE TABLE "encounterProtectionMethod"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL REFERENCES "encounter"("id") ON DELETE CASCADE,
                "protectionMethod" TEXT NOT NULL
            ) STRICT
        """)
        .execute(db)
        
        // Create junction table for encounter-partner relationships
        try #sql("""
            CREATE TABLE "encounterPartner"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "encounterId" TEXT NOT NULL REFERENCES "encounter"("id") ON DELETE CASCADE,
                "partnerId" TEXT NOT NULL REFERENCES "partner"("id") ON DELETE CASCADE
                --UNIQUE("encounterId", "partnerId")
            ) STRICT
        """)
        .execute(db)
    }
}
