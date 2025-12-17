//
//  Partner.swift
//  Fuckify
//
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Partner {
    // Basic Information
    var name: String = ""
    var notes: String = ""

    // Contact Details
    var phoneNumber: String = ""

    // Health Status
    var isOnPrep: Bool = false

    // Relationship Context
    var relationshipType: RelationshipType = RelationshipType.casual
    var dateMet: Date?

    // Appearance
    var avatarColor: String = ""

    // Metadata
    var dateAdded: Date = Date()
    var lastEncounterDate: Date?

    // Inverse Relationship
    @Relationship(deleteRule: .nullify) var encounters: [Encounter]? = []

    init(
        name: String,
        notes: String = "",
        phoneNumber: String = "",
        isOnPrep: Bool = false,
        relationshipType: RelationshipType = .casual,
        dateMet: Date? = nil,
        dateAdded: Date = Date(),
        avatarColor: String? = nil
    ) {
        self.name = name
        self.notes = notes
        self.phoneNumber = phoneNumber
        self.isOnPrep = isOnPrep
        self.relationshipType = relationshipType
        self.dateMet = dateMet
        self.dateAdded = dateAdded
        self.lastEncounterDate = nil
        self.avatarColor = avatarColor ?? Partner.randomColorName()
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

    // Computed property to get SwiftUI Color from string
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
}

// MARK: - Relationship Type Enum

enum RelationshipType: String, Codable {
    case casual = "Casual"
    case regular = "Regular"
    case committed = "Committed"
    case oneTime = "One-Time"
    case other = "Other"

    var displayName: String {
        self.rawValue
    }
}
