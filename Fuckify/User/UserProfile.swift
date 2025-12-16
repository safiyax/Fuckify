//
//  UserProfile.swift
//  Fuckify
//
//

import Foundation
import SwiftUI

@Observable
class UserProfile {
    static let shared = UserProfile()

    var name: String {
        get {
            UserDefaults.standard.string(forKey: "userName") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userName")
        }
    }

    var dateOfBirth: Date? {
        get {
            UserDefaults.standard.object(forKey: "userDateOfBirth") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userDateOfBirth")
        }
    }

    var isOnPrep: Bool {
        get {
            UserDefaults.standard.bool(forKey: "userIsOnPrep")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userIsOnPrep")
        }
    }

    var lastSTITestDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "userLastSTITestDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userLastSTITestDate")
        }
    }

    var notes: String {
        get {
            UserDefaults.standard.string(forKey: "userNotes") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userNotes")
        }
    }

    private init() {}

    // Computed properties
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year
    }

    var initials: String {
        if name.isEmpty {
            return "?"
        }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var hasProfile: Bool {
        !name.isEmpty
    }
}
