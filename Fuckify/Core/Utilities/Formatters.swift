//
//  Formatters.swift
//  Fuckify
//
//  Cached formatter instances to avoid creating them on every render
//  Creating formatters is expensive - cache and reuse them
//

import Foundation

enum Formatters {
    /// ISO8601 formatter for date-only strings (yyyy-MM-dd)
    /// Used for CSV export with dash separators
    static let iso8601DateOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }()
    
    /// ISO8601 formatter for full timestamps
    /// Used for database export filenames
    static let iso8601Full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    /// Date formatter for parsing CSV dates (yyyy-MM-dd)
    /// Uses local timezone to avoid date shifting
    static let csvDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
