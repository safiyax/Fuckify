//
//  AppDatabase.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import Foundation
//import OSLog
import SQLiteData

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "Database")


func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    
    // Enable foreign key enforcement for data integrity
    // This ensures ON DELETE CASCADE constraints are enforced
    configuration.foreignKeysEnabled = true

    // Check for pending database import (stored as Data in UserDefaults)
    if let databaseData = UserDefaults.standard.data(forKey: "pendingDatabaseImport") {
        logger.info("Found pending database import: \(databaseData.count) bytes")
        
        do {
            let tempDB = try defaultDatabase(configuration: configuration)
            let destinationPathString = tempDB.path
            try tempDB.close()

            let destinationURL: URL
            if destinationPathString.hasPrefix("file://") {
                destinationURL = URL(string: destinationPathString)!
            } else {
                destinationURL = URL(fileURLWithPath: destinationPathString)
            }

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try databaseData.write(to: destinationURL)
            UserDefaults.standard.removeObject(forKey: "pendingDatabaseImport")
            logger.info("Pending database import completed successfully")

        } catch {
            logger.error("Failed to import database: \(error)")
            // Clear the flag to prevent an infinite crash loop
            UserDefaults.standard.removeObject(forKey: "pendingDatabaseImport")
        }
    }

#if DEBUG
    configuration.prepareDatabase { db in
        db.trace(options: .profile) { event in
            if context == .preview {
                // Use .description (statement text only, no bound values) to avoid logging PII
                logger.debug("\(event.description)")
            } else if case .profile(_, let duration) = event, duration > 0.1 {
                // Log duration only — statement text may contain bound parameter values
                logger.warning("Slow query: \(String(format: "%.2f", duration * 1000))ms")
            }
        }
    }
#endif

    let database = try defaultDatabase(configuration: configuration)
    logger.info("Database opened at: \(database.path)")
    var migrator = DatabaseMigrator()

#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = false
#endif

    migrator.registerMigration("Create tables") { db in
        try CreateTables.migrate(db)
    }
    migrator.registerMigration("Add customization tables") { db in
        try AddCustomizationTables.migrate(db)
    }
    migrator.registerMigration("Fix junction table schema") { db in
        try FixJunctionTableSchema.migrate(db)
    }
    migrator.registerMigration("Add foreign key indexes") { db in
        try AddForeignKeyIndexes.migrate(db)
    }
    migrator.registerMigration("Add unique constraints") { db in
        try AddUniqueConstraints.migrate(db)
    }
    migrator.registerMigration("Remove deprecated enum columns") { db in
        try RemoveDeprecatedEnumColumns.migrate(db)
    }
    migrator.registerMigration("Add partner attributes") { db in
        try AddPartnerAttributes.migrate(db)
    }
    migrator.registerMigration("Update partner last encounter date") { db in
        try UpdatePartnerLastEncounterDate.migrate(db)
    }
    migrator.registerMigration("Add STI tables") { db in
        try AddSTITables.migrate(db)
    }

    // Note: SwiftData migration has been removed since all data has been migrated
    // If you need to re-migrate data, restore from git history:
    // - Fuckify/Database/Migrations/SwiftDataTransfer.swift
    // - Partner.swift, Encounter.swift, Item.swift

    try migrator.migrate(database)
    return database
}
