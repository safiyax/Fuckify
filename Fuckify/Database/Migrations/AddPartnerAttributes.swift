//
//  AddPartnerAttributes.swift
//  Fuckify
//
//  Migration to add customizable partner attributes system
//

import Foundation
import SQLiteData

struct AddPartnerAttributes {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create partnerAttributeType table
        try #sql("""
            CREATE TABLE "partnerAttributeType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "fieldType" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL,
                "enumChoices" TEXT
            ) STRICT
        """)
        .execute(db)
        
        // 2. Create partnerAttributeValue table
        try #sql("""
            CREATE TABLE "partnerAttributeValue"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "partnerId" TEXT NOT NULL,
                "attributeTypeId" TEXT NOT NULL,
                "value" TEXT NOT NULL,
                FOREIGN KEY("partnerId") REFERENCES "partner"("id") ON DELETE CASCADE,
                FOREIGN KEY("attributeTypeId") REFERENCES "partnerAttributeType"("id") ON DELETE CASCADE,
                UNIQUE("partnerId", "attributeTypeId")
            ) STRICT
        """)
        .execute(db)
        
        // 3. Create indexes for better query performance
        try #sql("""
            CREATE INDEX "idx_partnerAttributeValue_partnerId" 
            ON "partnerAttributeValue"("partnerId")
        """)
        .execute(db)
        
        try #sql("""
            CREATE INDEX "idx_partnerAttributeValue_attributeTypeId" 
            ON "partnerAttributeValue"("attributeTypeId")
        """)
        .execute(db)
        
        // 4. Seed built-in attribute types
        let builtInAttributes: [(UUID, String, String, String, String?)] = [
            (
                SQLPartnerAttributeType.lastSTITestId,
                "Last STI Test",
                "date",
                "calendar.badge.clock",
                nil
            ),
            (
                SQLPartnerAttributeType.hivStatusId,
                "HIV Status",
                "enum",
                "cross.fill",
                ["Negative", "Positive", "Unknown"].toJSONString()
            ),
            (
                SQLPartnerAttributeType.onBirthControlId,
                "On Birth Control",
                "boolean",
                "pills.circle.fill",
                nil
            ),
            (
                SQLPartnerAttributeType.onPrepId,
                "On PrEP",
                "boolean",
                "pills.fill",
                nil
            )
        ]
        
        for (index, (id, name, fieldType, icon, enumChoices)) in builtInAttributes.enumerated() {
            try db.execute(
                sql: """
                INSERT INTO "partnerAttributeType" 
                ("id", "name", "fieldType", "icon", "isBuiltIn", "isEnabled", "sortOrder", "dateAdded", "enumChoices")
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    id.uuidString,
                    name,
                    fieldType,
                    icon,
                    true,  // isBuiltIn
                    true,  // isEnabled
                    index, // sortOrder
                    Date(),
                    enumChoices
                ]
            )
        }
        
        // 5. Migrate existing isOnPrep data to custom attribute
        // Fetch partners with isOnPrep = true
        let partnerIds = try String.fetchAll(
            db,
            sql: "SELECT id FROM partner WHERE isOnPrep = 1"
        )
        
        // Insert attribute value for each partner
        for partnerIdString in partnerIds {
            try db.execute(
                sql: """
                INSERT INTO "partnerAttributeValue" ("id", "partnerId", "attributeTypeId", "value")
                VALUES (?, ?, ?, ?)
                """,
                arguments: [
                    UUID().uuidString,
                    partnerIdString,
                    SQLPartnerAttributeType.onPrepId.uuidString,
                    "true"
                ]
            )
        }
        
        // 6. Drop the isOnPrep column (now using custom attributes)
        try db.execute(sql: """
            ALTER TABLE "partner" DROP COLUMN "isOnPrep"
        """)
    }
}
