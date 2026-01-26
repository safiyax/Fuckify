//
//  String+Initials.swift
//  Fuckify
//
//  Extension for generating initials from names
//

import Foundation

extension String {
    /// Generates initials from a name string
    /// - Returns: Uppercase initials (1-2 characters), or "?" if empty
    ///
    /// Examples:
    /// - "John Doe" → "JD"
    /// - "Alice" → "AL"
    /// - "" → "?"
    var initials: String {
        let components = split(separator: " ")
        
        if components.count >= 2 {
            // Two or more words: use first letter of first and second words
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            // Single word: use first two letters
            return String(first.prefix(2)).uppercased()
        } else {
            // Empty string
            return "?"
        }
    }
}
