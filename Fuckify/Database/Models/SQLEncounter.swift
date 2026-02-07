//
//  Encounter.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

@Table("encounter")
struct SQLEncounter: Identifiable {
    // Primary Key
    let id: UUID
    
    // Date and Time
    var date: Date?
    var duration: TimeInterval = 0 // in seconds

    // Location and Notes
    var location: String = ""
    var notes: String = ""
    
    // Experience
    var rating: Int = 5 // 1-5 stars
    var reachedOrgasm: Bool = false
    
    // Metadata
    var dateAdded: Date = Date()
    

    // Computed property for formatted duration
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}


// MARK: - Activity Type Entity (Customizable)

@Table("activityType")
struct SQLActivityTypeEntity: Identifiable {
    let id: UUID
    var name: String
    var icon: String           // SF Symbol name
    var isBuiltIn: Bool        // true for defaults, false for custom
    var isEnabled: Bool        // visibility toggle
    var sortOrder: Int         // for display ordering
    var dateAdded: Date
    
    init(
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

// MARK: - Protection Method Entity (Customizable)

@Table("protectionMethodType")
struct SQLProtectionMethodEntity: Identifiable {
    let id: UUID
    var name: String
    var icon: String           // SF Symbol name
    var isBuiltIn: Bool        // true for defaults, false for custom
    var isEnabled: Bool        // visibility toggle
    var sortOrder: Int         // for display ordering
    var dateAdded: Date
    
    init(
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

// MARK: - Junction Tables

@Table("encounterActivity")
struct EncounterActivity: Identifiable {
    let id: UUID
    var encounterId: UUID
    var activityTypeId: UUID?           // NEW: UUID reference
    var activityType: SQLActivityType?  // OLD: Keep for migration safety
    
    init(
        id: UUID = UUID(),
        encounterId: UUID,
        activityTypeId: UUID? = nil,
        activityType: SQLActivityType? = nil
    ) {
        self.id = id
        self.encounterId = encounterId
        self.activityTypeId = activityTypeId
        self.activityType = activityType
    }
}

@Table("encounterProtectionMethod")
struct EncounterProtectionMethod: Identifiable {
    let id: UUID
    var encounterId: UUID
    var protectionMethodId: UUID?              // NEW: UUID reference
    var protectionMethod: SQLProtectionMethod? // OLD: Keep for migration safety
    
    init(
        id: UUID = UUID(),
        encounterId: UUID,
        protectionMethodId: UUID? = nil,
        protectionMethod: SQLProtectionMethod? = nil
    ) {
        self.id = id
        self.encounterId = encounterId
        self.protectionMethodId = protectionMethodId
        self.protectionMethod = protectionMethod
    }
}

// MARK: - Legacy Enums (Deprecated - Keep for migration)

enum SQLActivityType: String, Codable, CaseIterable, QueryBindable {
    case oral = "Oral"
    case vaginal = "Vaginal"
    case anal = "Anal"
    case manual = "Manual"
    case kissing = "Kissing"
    case other = "Other"
    
    var displayName: String {
        self.rawValue
    }
    
    var icon: String {
        switch self {
        case .oral: return "mouth"
        case .vaginal: return "heart.fill"
        case .anal: return "circle.fill"
        case .manual: return "hand.raised.fill"
        case .kissing: return "face.smiling"
        case .other: return "ellipsis.circle"
        }
    }
    
    // Predefined UUIDs for built-in activities (stable across installations)
    var predefinedUUID: UUID {
        switch self {
        case .oral:    return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .vaginal: return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case .anal:    return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        case .manual:  return UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        case .kissing: return UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        case .other:   return UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        }
    }
    
    // Convert to entity representation
    func toEntity(sortOrder: Int, isEnabled: Bool = true) -> SQLActivityTypeEntity {
        SQLActivityTypeEntity(
            id: predefinedUUID,
            name: displayName,
            icon: icon,
            isBuiltIn: true,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            dateAdded: Date()
        )
    }
}

enum SQLProtectionMethod: String, Codable, CaseIterable, QueryBindable {
    case condom = "Condom"
    case prep = "PrEP"
    case pullOut = "Pull Out"
    case none = "None"
    case other = "Other"
    
    var displayName: String {
        self.rawValue
    }
    
    var icon: String {
        switch self {
        case .condom: return "shield.fill"
        case .prep: return "pills.fill"
        case .pullOut: return "arrow.uturn.backward"
        case .none: return "xmark.circle"
        case .other: return "ellipsis.circle"
        }
    }
    
    // Predefined UUIDs for built-in protection methods (stable across installations)
    var predefinedUUID: UUID {
        switch self {
        case .condom:  return UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        case .prep:    return UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        case .pullOut: return UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        case .none:    return UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        case .other:   return UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
        }
    }
    
    // Convert to entity representation
    func toEntity(sortOrder: Int, isEnabled: Bool = true) -> SQLProtectionMethodEntity {
        SQLProtectionMethodEntity(
            id: predefinedUUID,
            name: displayName,
            icon: icon,
            isBuiltIn: true,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            dateAdded: Date()
        )
    }
}
