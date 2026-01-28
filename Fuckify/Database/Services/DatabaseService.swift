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
