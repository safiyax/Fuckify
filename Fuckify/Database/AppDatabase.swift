//
//  AppDatabase.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-05.
//

import OSLog
import SwiftData
import SQLiteData


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
    migrator.eraseDatabaseOnSchemaChange = false
#endif
    // Register migrations
    migrator.registerMigration("Create tables") { db in
        try CreateTables.migrate(db)
    }
    
    migrator.registerMigration("SwiftData transfer") { db in
        let swiftDataContainer = try ModelContainer(
            for: Partner.self, Encounter.self
        )
        let modelContext = ModelContext(swiftDataContainer)
        
        try SwiftDataTransfer.migrate(db, modelContext: modelContext)
    }
    
    try migrator.migrate(database)
    return database
}

private let logger = Logger(subsystem: "Fuckify", category: "Database")
