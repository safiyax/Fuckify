//
//  UserSettings.swift
//  Fuckify
//
//

import Foundation
import SwiftUI

@Observable
class UserSettings {
    static let shared = UserSettings()

    // Activity preferences
    var enabledActivities: Set<ActivityType> {
        get {
            if let data = UserDefaults.standard.data(forKey: "enabledActivities"),
               let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return Set(decoded.compactMap { ActivityType(rawValue: $0) })
            }
            // Default: all activities enabled
            return Set(ActivityType.allCases)
        }
        set {
            let encoded = try? JSONEncoder().encode(Set(newValue.map { $0.rawValue }))
            UserDefaults.standard.set(encoded, forKey: "enabledActivities")
        }
    }

    // Protection method preferences
    var enabledProtectionMethods: Set<ProtectionMethod> {
        get {
            if let data = UserDefaults.standard.data(forKey: "enabledProtectionMethods"),
               let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return Set(decoded.compactMap { ProtectionMethod(rawValue: $0) })
            }
            // Default: all protection methods enabled
            return Set(ProtectionMethod.allCases)
        }
        set {
            let encoded = try? JSONEncoder().encode(Set(newValue.map { $0.rawValue }))
            UserDefaults.standard.set(encoded, forKey: "enabledProtectionMethods")
        }
    }

    private init() {}

    // Helper methods
    func isActivityEnabled(_ activity: ActivityType) -> Bool {
        enabledActivities.contains(activity)
    }

    func toggleActivity(_ activity: ActivityType) {
        if enabledActivities.contains(activity) {
            enabledActivities.remove(activity)
        } else {
            enabledActivities.insert(activity)
        }
    }

    func isProtectionMethodEnabled(_ method: ProtectionMethod) -> Bool {
        enabledProtectionMethods.contains(method)
    }

    func toggleProtectionMethod(_ method: ProtectionMethod) {
        if enabledProtectionMethods.contains(method) {
            enabledProtectionMethods.remove(method)
        } else {
            enabledProtectionMethods.insert(method)
        }
    }
}
