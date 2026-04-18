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
    
    /// Import (restore) a database from a source file URL.
    ///
    /// Runs all app migrations against the source database first so that an
    /// older-schema backup is brought up to the current schema before being
    /// copied into the live pool. Without this step, columns added by newer
    /// migrations would be missing after the import.
    ///
    /// Uses `source.backup(to: database)` which internally opens a read context
    /// on the source — matching the pattern GRDB uses in `DatabaseReader.backup(to:)`.
    /// Using `source.write { }` instead would acquire a BEGIN IMMEDIATE transaction
    /// on the source, causing SQLITE_BUSY (error 5) from the backup API's internal
    /// read lock acquisition.
    func importDatabase(from sourceURL: URL) throws {
        let source = try DatabasePool(path: sourceURL.path)
        try appMigrator().migrate(source)
        try source.backup(to: database)

        // Close the source pool before cleaning up sidecar files.
        // Opening a DatabasePool on the source creates -wal and -shm files
        // next to it; closing checkpoints the WAL and allows safe deletion.
        try source.close()
        let fm = FileManager.default
        for suffix in ["-wal", "-shm"] {
            let sidecar = sourceURL.deletingLastPathComponent()
                .appendingPathComponent(sourceURL.lastPathComponent + suffix)
            if fm.fileExists(atPath: sidecar.path) {
                try fm.removeItem(at: sidecar)
            }
        }

        // sqlite3_backup_step writes pages directly at the SQLite engine level,
        // bypassing the commit hook that GRDB's ValueObservation relies on.
        // notifyChanges(in:) must be called from inside a write transaction to
        // trigger the commit hook path that ValueObservation subscribes to.
        try database.write { db in
            try db.notifyChanges(in: .fullDatabase)
        }
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
