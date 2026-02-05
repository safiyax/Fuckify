//
//  PartnerData.swift
//  Fuckify
//
//  Lightweight partner model for Live Activity
//  Must be Codable and Hashable for ActivityAttributes
//

import Foundation
import SwiftUI

/// Simplified partner data for Live Activity
/// Cannot use SQLPartner directly as it's not Codable for ActivityKit
struct PartnerData: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let avatarColor: String
    
    #if !WIDGET_EXTENSION
    /// Convert from SQLPartner to PartnerData (main app only)
    init(from partner: SQLPartner) {
        self.id = partner.id
        self.name = partner.name
        self.avatarColor = partner.avatarColor
    }
    #endif
    
    /// Direct initializer
    init(id: UUID, name: String, avatarColor: String) {
        self.id = id
        self.name = name
        self.avatarColor = avatarColor
    }
    
    /// Get partner initials for display
    var initials: String {
        name.initials
    }
    
    /// Get SwiftUI color from color name
    var color: Color {
        Color.fromPartnerColorName(avatarColor)
    }
}
