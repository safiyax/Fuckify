//
//  PartnerColors.swift
//  Fuckify
//
//  Centralized partner color management
//

import Foundation

/// Utility for managing available partner avatar colors
enum PartnerColors {
    /// All available color names for partner avatars
    nonisolated static let allColorNames: [String] = [
        "blue",
        "purple",
        "pink",
        "red",
        "orange",
        "yellow",
        "green",
        "teal",
        "indigo"
    ]
    
    /// Generates a random color name from the available colors
    /// - Returns: A random color name string
    /// - Note: Must be nonisolated to be used in struct defaults and initializers
    nonisolated static func randomColorName() -> String {
        allColorNames.randomElement() ?? "blue"
    }
    
    /// Validates if a color name is in the available list
    /// - Parameter colorName: The color name to validate
    /// - Returns: `true` if the color is valid, `false` otherwise
    nonisolated static func isValid(_ colorName: String) -> Bool {
        allColorNames.contains(colorName)
    }
}
