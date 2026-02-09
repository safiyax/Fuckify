//
//  AppDatabase.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    
    // Enable foreign key enforcement for data integrity
    // This ensures ON DELETE CASCADE constraints are enforced
    configuration.foreignKeysEnabled = true
    
    // Log to file for debugging
    let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("import_log.txt")
    func log(_ message: String) {
        print(message)
        if let data = (message + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    
    log("📥 Checking for pending database import...")
    
    // Check for pending database import (stored as Data in UserDefaults)
    if let databaseData = UserDefaults.standard.data(forKey: "pendingDatabaseImport") {
        log("📥 Found pending database import: \(databaseData.count) bytes")
        
        do {
            // Get the default database path
            let tempDB = try defaultDatabase(configuration: configuration)
            let destinationPathString = tempDB.path
            log("📥 Destination path string: \(destinationPathString)")
            
            // Close the temp database connection
            try tempDB.close()
            log("📥 Closed temp database")
            
            // Parse the destination path (handle both file:// URLs and plain paths)
            let destinationURL: URL
            if destinationPathString.hasPrefix("file://") {
                destinationURL = URL(string: destinationPathString)!
            } else {
                destinationURL = URL(fileURLWithPath: destinationPathString)
            }
            let destinationPath = destinationURL.path
            log("📥 Destination file path: \(destinationPath)")
            
            // Remove existing database if present
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(at: destinationURL)
                log("📥 Removed existing database")
            }
            
            // Write the imported database data
            try databaseData.write(to: destinationURL)
            log("📥 Imported database written successfully")
            
            // Clear the pending import flag
            UserDefaults.standard.removeObject(forKey: "pendingDatabaseImport")
            log("📥 Pending import completed")
            
        } catch {
            log("📥 ❌ Failed to import database: \(error)")
            // Clear the flag to prevent infinite crash loop
            UserDefaults.standard.removeObject(forKey: "pendingDatabaseImport")
            // Continue with normal database initialization
        }
    } else {
        log("📥 No pending import found")
    }
    
#if DEBUG
    configuration.prepareDatabase { db in
        db.trace(options: .profile) { event in
            // Log all queries in preview mode
            if context == .preview {
                print("\(event.expandedDescription)")
            } else {
                // In normal DEBUG mode, only log slow queries (>100ms)
                if case .profile(let statement, let duration) = event, duration > 0.1 {
                    print("⚠️ Slow query (\(String(format: "%.2f", duration * 1000))ms): \(statement)")
                }
                // Still log all queries at debug level for detailed debugging
                print("DEBUG: \(event.expandedDescription)")
            }
        }
    }
#endif
    
    let database = try defaultDatabase(configuration: configuration)
    print("database path: \(database.path)")
    var migrator = DatabaseMigrator()
    
#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = false
#endif
    
    // Register migrations
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
    
    // Note: SwiftData migration has been removed since all data has been migrated
    // If you need to re-migrate data, restore from git history:
    // - Fuckify/Database/Migrations/SwiftDataTransfer.swift
    // - Partner.swift, Encounter.swift, Item.swift
    
    try migrator.migrate(database)
    return database
}
