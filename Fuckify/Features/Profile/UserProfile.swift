//
//  UserProfile.swift
//  Fuckify
//
//  User profile data model with proper observation support.
//  Uses stored properties with didSet observers for proper SwiftUI observation.
//

import Foundation
import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "UserProfile")

/// User profile information stored in UserDefaults.
@MainActor
@Observable
final class UserProfile {
    // MARK: - Stored Properties

    var name: String {
        didSet {
            UserDefaults.standard.set(name, forKey: "userName")
            lastModified = Date()
        }
    }

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

    var notes: String {
        didSet {
            UserDefaults.standard.set(notes, forKey: "userNotes")
            lastModified = Date()
        }
    }

    var lastModified: Date {
        didSet {
            UserDefaults.standard.set(lastModified, forKey: "userLastModified")
        }
    }

    /// Testing interval in days for STI reminders (default: 90)
    var stiTestingIntervalDays: Int {
        didSet {
            UserDefaults.standard.set(stiTestingIntervalDays, forKey: "stiTestingIntervalDays")
        }
    }

    /// Whether STI test reminders are enabled
    var stiRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(stiRemindersEnabled, forKey: "stiRemindersEnabled")
        }
    }

    // MARK: - Initialization

    init() {
        self.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.dateOfBirth = UserDefaults.standard.object(forKey: "userDateOfBirth") as? Date
        self.notes = UserDefaults.standard.string(forKey: "userNotes") ?? ""
        self.lastModified = UserDefaults.standard.object(forKey: "userLastModified") as? Date ?? Date()
        let interval = UserDefaults.standard.integer(forKey: "stiTestingIntervalDays")
        self.stiTestingIntervalDays = interval > 0 ? interval : 90
        self.stiRemindersEnabled = UserDefaults.standard.bool(forKey: "stiRemindersEnabled")
    }

    // MARK: - Computed Properties

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    var initials: String { name.initials }

    var hasProfile: Bool { !name.isEmpty }

    func clearProfile() {
        logger.info("Clearing user profile")
        name = ""
        dateOfBirth = nil
        notes = ""
        stiTestingIntervalDays = 90
        stiRemindersEnabled = false
    }
}
