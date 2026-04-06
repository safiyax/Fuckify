//
//  STIService.swift
//  Fuckify
//
//  Service layer for STI test CRUD operations (mirrors PartnerService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIService")

struct STIService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    /// Fetch all STI tests sorted by date descending (newest first)
    func fetchAll() throws -> [SQLSTITest] {
        try database.read { db in
            try SQLSTITest
                .order { $0.date.desc() }
                .fetchAll(db)
        }
    }

    /// Fetch the most recent STI test
    func fetchLatest() throws -> SQLSTITest? {
        try database.read { db in
            try SQLSTITest
                .order { $0.date.desc() }
                .fetchOne(db)
        }
    }

    // MARK: - Create

    /// Create a new STI test record and return its ID
    func create(date: Date, resultTypeId: UUID, notes: String) throws -> UUID {
        try database.write { db in
            let test = SQLSTITest(
                id: UUID(),
                date: date,
                resultTypeId: resultTypeId,
                notes: notes,
                dateAdded: Date()
            )
            try SQLSTITest.insert { test }.execute(db)
            logger.info("Created STI test: \(test.id)")
            return test.id
        }
    }

    // MARK: - Update

    /// Update an existing STI test record
    func update(_ test: SQLSTITest) throws {
        try database.write { db in
            try SQLSTITest.update(test).execute(db)
            logger.info("Updated STI test: \(test.id)")
        }
    }

    // MARK: - Delete

    /// Delete a STI test record by ID
    func delete(_ id: UUID) throws {
        try database.write { db in
            try SQLSTITest
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted STI test: \(id)")
        }
    }
}

// MARK: - Dependency Key

extension STIService: DependencyKey {
    nonisolated static var liveValue: STIService { STIService() }
}

extension DependencyValues {
    var stiService: STIService {
        get { self[STIService.self] }
        set { self[STIService.self] = newValue }
    }
}
