//
//  AppDatabase.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import OSLog
import SQLiteData

private nonisolated(unsafe) let logger = Logger(subsystem: "Fuckify", category: "Database")

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    
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
        db.trace(options: .profile) {
            if context == .preview {
                print("\($0.expandedDescription)")
            } else {
                logger.debug("\($0.expandedDescription)")
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
    
    // Note: SwiftData migration has been removed since all data has been migrated
    // If you need to re-migrate data, restore from git history:
    // - Fuckify/Database/Migrations/SwiftDataTransfer.swift
    // - Partner.swift, Encounter.swift, Item.swift
    
    try migrator.migrate(database)
    return database
}
