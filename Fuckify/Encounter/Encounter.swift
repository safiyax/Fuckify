//
//  Encounter.swift
//  Fuckify
//
//

import Foundation
import SwiftData

@Model
final class Encounter {
    // Date and Time
    var date: Date = Date()
    var duration: TimeInterval = 0 // in seconds

    // Activities and Protection
    var activities: [ActivityType] = []
    var protectionMethods: [ProtectionMethod] = []

    // Location and Notes
    var location: String = ""
    var notes: String = ""

    // Experience
    var rating: Int = 0 // 1-5 stars
    var reachedOrgasm: Bool = false

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Partner.encounters) var partners: [Partner]? = []

    // Metadata
    var dateAdded: Date = Date()

    init(
        date: Date = Date(),
        duration: TimeInterval = 0,
        activities: [ActivityType] = [],
        protectionMethods: [ProtectionMethod] = [],
        location: String = "",
        notes: String = "",
        rating: Int = 0,
        reachedOrgasm: Bool = false,
        partners: [Partner] = [],
        dateAdded: Date = Date()
    ) {
        self.date = date
        self.duration = duration
        self.activities = activities
        self.protectionMethods = protectionMethods
        self.location = location
        self.notes = notes
        self.rating = rating
        self.reachedOrgasm = reachedOrgasm
        self.partners = partners
        self.dateAdded = dateAdded
    }

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

    // Computed property for partner names
    var partnerNames: String {
        guard let partners = partners, !partners.isEmpty else {
            return "Unknown"
        }
        return partners.map { $0.name }.joined(separator: ", ")
    }
}

// MARK: - Activity Type Enum

enum ActivityType: String, Codable, CaseIterable {
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

// MARK: - Protection Method Enum

enum ProtectionMethod: String, Codable, CaseIterable {
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
