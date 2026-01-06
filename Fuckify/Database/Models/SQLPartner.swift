//
//  Partner.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2026-01-05.
//

import Foundation
import SwiftUI
import SQLiteData

@Table("partner")
struct SQLPartner {
    let id: UUID
    
    var name = ""
    var notes = ""

    // Contact Details
    var phoneNumber = ""

    // Health Status
    var isOnPrep = false

    // Relationship Context
    var relationshipType: SQLRelationshipType = .casual
    var dateMet: Date?

    // Appearance
    var avatarColor: String = SQLPartner.randomColorName()

    // Metadata
    var dateAdded: Date = Date()
    var lastEncounterDate: Date?
    var isPinned = false
    
    
    var color: Color {
        switch avatarColor {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
    }
    
    // Static method to generate random color name
    static func randomColorName() -> String {
        let colors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "indigo"]
        return colors.randomElement() ?? "blue"
    }

    // Computed property to get initials for avatar
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
}

enum SQLRelationshipType: String, Codable, QueryBindable {
    case casual = "Casual"
    case regular = "Regular"
    case committed = "Committed"
    case oneTime = "One-Time"
    case other = "Other"

    var displayName: String {
        self.rawValue
    }
}

