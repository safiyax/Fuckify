//
//  UserSettings.swift
//  Fuckify
//
//

import Foundation
import SwiftUI

@Observable
class UserSettings {
    @MainActor static let shared = UserSettings()

    // Activity preferences
    var enabledActivities: Set<SQLActivityType> {
        get {
            if let data = UserDefaults.standard.data(forKey: "enabledActivities"),
               let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return Set(decoded.compactMap { SQLActivityType(rawValue: $0) })
            }
            // Default: all activities enabled
            return Set(SQLActivityType.allCases)
        }
        set {
            let encoded = try? JSONEncoder().encode(Set(newValue.map { $0.rawValue }))
            UserDefaults.standard.set(encoded, forKey: "enabledActivities")
        }
    }

    // Protection method preferences
    var enabledProtectionMethods: Set<SQLProtectionMethod> {
        get {
            if let data = UserDefaults.standard.data(forKey: "enabledProtectionMethods"),
               let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return Set(decoded.compactMap { SQLProtectionMethod(rawValue: $0) })
            }
            // Default: all protection methods enabled
            return Set(SQLProtectionMethod.allCases)
        }
        set {
            let encoded = try? JSONEncoder().encode(Set(newValue.map { $0.rawValue }))
            UserDefaults.standard.set(encoded, forKey: "enabledProtectionMethods")
        }
    }

    private init() {}

    // Helper methods
    func isActivityEnabled(_ activity: SQLActivityType) -> Bool {
        enabledActivities.contains(activity)
    }

    func toggleActivity(_ activity: SQLActivityType) {
        if enabledActivities.contains(activity) {
            enabledActivities.remove(activity)
        } else {
            enabledActivities.insert(activity)
        }
    }

    func isProtectionMethodEnabled(_ method: SQLProtectionMethod) -> Bool {
        enabledProtectionMethods.contains(method)
    }

    func toggleProtectionMethod(_ method: SQLProtectionMethod) {
        if enabledProtectionMethods.contains(method) {
            enabledProtectionMethods.remove(method)
        } else {
            enabledProtectionMethods.insert(method)
        }
    }
}
