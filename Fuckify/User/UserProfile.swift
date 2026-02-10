//
//  UserProfile.swift
//  Fuckify
//
//  User profile data model with proper observation support
//  Uses stored properties with didSet observers for proper SwiftUI observation
//

import Foundation
import SwiftUI

/// User profile information stored in UserDefaults
/// 
/// Uses stored properties instead of computed properties to ensure
/// SwiftUI's @Observable system properly tracks changes.
@MainActor
@Observable
final class UserProfile {
    // MARK: - Stored Properties
    
    /// User's name
    var name: String {
        didSet {
            UserDefaults.standard.set(name, forKey: "userName")
            lastModified = Date()
        }
    }
    
    /// User's date of birth (optional)
    var dateOfBirth: Date? {
        didSet {
            if let date = dateOfBirth {
                UserDefaults.standard.set(date, forKey: "userDateOfBirth")
            } else {
                UserDefaults.standard.removeObject(forKey: "userDateOfBirth")
            }
            lastModified = Date()
        }
    }
    
    /// Whether user is on PrEP (HIV prevention medication)
    var isOnPrep: Bool {
        didSet {
            UserDefaults.standard.set(isOnPrep, forKey: "userIsOnPrep")
            lastModified = Date()
        }
    }
    
    /// Date of user's last STI test (optional)
    var lastSTITestDate: Date? {
        didSet {
            if let date = lastSTITestDate {
                UserDefaults.standard.set(date, forKey: "userLastSTITestDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "userLastSTITestDate")
            }
            lastModified = Date()
        }
    }
    
    /// User's notes about their profile
    var notes: String {
        didSet {
            UserDefaults.standard.set(notes, forKey: "userNotes")
            lastModified = Date()
        }
    }
    
    /// Date when profile was last modified
    var lastModified: Date {
        didSet {
            UserDefaults.standard.set(lastModified, forKey: "userLastModified")
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize user profile, loading values from UserDefaults
    init() {
        // Load values from UserDefaults
        self.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.dateOfBirth = UserDefaults.standard.object(forKey: "userDateOfBirth") as? Date
        self.isOnPrep = UserDefaults.standard.bool(forKey: "userIsOnPrep")
        self.lastSTITestDate = UserDefaults.standard.object(forKey: "userLastSTITestDate") as? Date
        self.notes = UserDefaults.standard.string(forKey: "userNotes") ?? ""
        self.lastModified = UserDefaults.standard.object(forKey: "userLastModified") as? Date ?? Date()
    }

    // Computed properties
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year
    }

    var initials: String {
        name.initials
    }

    var hasProfile: Bool {
        !name.isEmpty
    }

    func clearProfile() {
        name = ""
        dateOfBirth = nil
        isOnPrep = false
        lastSTITestDate = nil
        notes = ""
    }
}
