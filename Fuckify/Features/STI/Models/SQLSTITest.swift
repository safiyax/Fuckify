//
//  SQLSTITest.swift
//  Fuckify

import Foundation
import SwiftUI
import SQLiteData

// MARK: - STI Test Result Type (Catalog table — mirrors activityType pattern)

@Table("stiTestResultType")
struct SQLSTITestResultType: Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var isBuiltIn: Bool     // true for built-ins, cannot be deleted
    var isEnabled: Bool     // visibility toggle
    var sortOrder: Int      // display ordering
    var dateAdded: Date

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.dateAdded = dateAdded
    }
}

// MARK: - Predefined UUIDs for Built-in Result Types

extension SQLSTITestResultType {
    nonisolated static let negativeId = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    nonisolated static let positiveId = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
    nonisolated static let pendingId  = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!

    nonisolated static var builtIns: [SQLSTITestResultType] {
        [
            SQLSTITestResultType(
                id: negativeId,
                name: "Negative",
                icon: "checkmark.circle.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 0,
                dateAdded: Date()
            ),
            SQLSTITestResultType(
                id: positiveId,
                name: "Positive",
                icon: "exclamationmark.triangle.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 1,
                dateAdded: Date()
            ),
            SQLSTITestResultType(
                id: pendingId,
                name: "Pending",
                icon: "clock.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 2,
                dateAdded: Date()
            ),
        ]
    }

    /// Display color for this result type
    var displayColor: Color {
        switch id {
        case SQLSTITestResultType.negativeId: return .green
        case SQLSTITestResultType.positiveId: return .red
        case SQLSTITestResultType.pendingId:  return .orange
        default: return .gray
        }
    }
}

// MARK: - STI Test Record

@Table("stiTest")
struct SQLSTITest: Identifiable {
    let id: UUID
    var date: Date
    var resultTypeId: UUID  // FK → stiTestResultType.id
    var notes: String = ""
    var dateAdded: Date

    nonisolated init(
        id: UUID = UUID(),
        date: Date,
        resultTypeId: UUID,
        notes: String = "",
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.resultTypeId = resultTypeId
        self.notes = notes
        self.dateAdded = dateAdded
    }
}
