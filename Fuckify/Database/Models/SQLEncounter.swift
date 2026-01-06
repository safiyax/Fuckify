//
//  Encounter.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

@Table("encounter")
struct SQLEncounter {
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


@Table("encounterActivity")
struct EncounterActivity {
    let id: UUID
    var encounterId: UUID
    var activityType: SQLActivityType
    
    init(
        id: UUID = UUID(),
        encounterId: UUID,
        activityType: SQLActivityType
    ) {
        self.id = id
        self.encounterId = encounterId
        self.activityType = activityType
    }
    
}

@Table("encounterProtectionMethod")
struct EncounterProtectionMethod {
    let id: UUID
    var encounterId: UUID
    var protectionMethod: SQLProtectionMethod
    
    init(
        id: UUID = UUID(),
        encounterId: UUID,
        protectionMethod: SQLProtectionMethod
    ) {
        self.id = id
        self.encounterId = encounterId
        self.protectionMethod = protectionMethod
    }
    
}

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
}
