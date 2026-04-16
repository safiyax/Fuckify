//
//  SQLPositionType.swift
//  Fuckify

import Foundation
import SQLiteData

// MARK: - Position Type (Catalog — mirrors activityType pattern)

@Table("positionType")
struct SQLPositionType: Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var isBuiltIn: Bool
    var isEnabled: Bool
    var sortOrder: Int
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

// MARK: - Predefined UUIDs

extension SQLPositionType {
    nonisolated static let topId     = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    nonisolated static let bottomId  = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    nonisolated static let switchId  = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!

    nonisolated static var builtIns: [SQLPositionType] {
        [
            SQLPositionType(id: topId,    name: "Top",    icon: "arrow.up.circle.fill",            isBuiltIn: true, isEnabled: true, sortOrder: 0, dateAdded: Date()),
            SQLPositionType(id: bottomId, name: "Bottom", icon: "arrow.down.circle.fill",          isBuiltIn: true, isEnabled: true, sortOrder: 1, dateAdded: Date()),
            SQLPositionType(id: switchId, name: "Switch", icon: "arrow.up.arrow.down.circle.fill", isBuiltIn: true, isEnabled: true, sortOrder: 2, dateAdded: Date()),
        ]
    }
}
