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
    migrator.eraseDatabaseOnSchemaChange = true
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
