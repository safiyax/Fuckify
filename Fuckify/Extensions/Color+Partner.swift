//
//  Color+Partner.swift
//  Fuckify
//
//  Extension for partner avatar colors
//

import SwiftUI

extension Color {
    /// Creates a Color from a partner color name string
    /// - Parameter colorName: The string name of the color (e.g., "blue", "purple", "pink")
    /// - Returns: The corresponding Color, or `.blue` as a fallback
    static func fromPartnerColorName(_ colorName: String) -> Color {
        switch colorName {
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
