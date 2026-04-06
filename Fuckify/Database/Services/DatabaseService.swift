//
//  DatabaseService.swift
//  Fuckify
//
//  Database service for database-level operations
//

import Foundation
import Dependencies
import SQLiteData

/// Service layer for database-level operations
struct DatabaseService {
    @Dependency(\.defaultDatabase) var database
    
    /// Get the file path to the SQLite database
    func getDatabasePath() throws -> String {
        database.path
    }
    
    /// Export the database to a destination file URL using GRDB's backup API.
    ///
    /// Using the backup API (rather than a raw file copy) ensures that data
    /// held in the WAL file is included in the export, giving a consistent
    /// snapshot of the full database regardless of checkpoint state.
    func exportDatabase(to destinationURL: URL) throws {
        // Remove any stale file at the destination first
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Open a DatabasePool at the destination path for the backup target
        let destDB = try DatabasePool(path: destinationURL.path)
        
        // backup(to:) performs a live, consistent copy including WAL data
        try database.backup(to: destDB)
    }
}

// MARK: - Dependency Registration

extension DatabaseService: DependencyKey {
    static let liveValue = DatabaseService()
}

extension DependencyValues {
    var databaseService: DatabaseService {
        get { self[DatabaseService.self] }
        set { self[DatabaseService.self] = newValue }
    }
}
