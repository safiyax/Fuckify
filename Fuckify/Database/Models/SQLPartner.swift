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
struct SQLPartner: Identifiable, Hashable {
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
    var avatarColor: String = "blue"

    // Metadata
    var dateAdded: Date = Date()
    var lastEncounterDate: Date?
    var isPinned = false
    
    
    var color: Color {
        .fromPartnerColorName(avatarColor)
    }
    
    // Static method to generate random color name
    // Note: Must be nonisolated to be used in struct defaults and initializers
    nonisolated static func randomColorName() -> String {
        PartnerColors.randomColorName()
    }

    // Computed property to get initials for avatar
    var initials: String {
        name.initials
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

