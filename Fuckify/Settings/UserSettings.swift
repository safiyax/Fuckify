//
//  UserSettings.swift
//  Fuckify
//
//

import Foundation
import SwiftUI
import Dependencies

@MainActor
@Observable
class UserSettings {
    static let shared = UserSettings()
    
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database
    
    private let customizationService = CustomizationService()

    private init() {}

    // MARK: - Database-backed Activity Preferences (NEW)
    
    /// Fetch all activity type entities from database
    func allActivityTypes() -> [SQLActivityTypeEntity] {
        (try? customizationService.fetchAllActivityTypes()) ?? []
    }
    
    /// Fetch only enabled activity type entities
    func enabledActivityTypes() -> [SQLActivityTypeEntity] {
        (try? customizationService.fetchEnabledActivityTypes()) ?? []
    }
    
    /// Check if activity type is enabled
    func isActivityEnabled(_ activityID: UUID) -> Bool {
        guard let entity = try? customizationService.fetchActivityType(id: activityID) else {
            return false
        }
        return entity.isEnabled
    }
    
    /// Toggle activity type enabled status
    func toggleActivity(_ activityID: UUID) {
        try? customizationService.toggleActivityType(id: activityID)
    }
    
    // MARK: - Database-backed Protection Method Preferences (NEW)
    
    /// Fetch all protection method entities from database
    func allProtectionMethods() -> [SQLProtectionMethodEntity] {
        (try? customizationService.fetchAllProtectionMethods()) ?? []
    }
    
    /// Fetch only enabled protection method entities
    func enabledProtectionMethods() -> [SQLProtectionMethodEntity] {
        (try? customizationService.fetchEnabledProtectionMethods()) ?? []
    }
    
    /// Check if protection method is enabled
    func isProtectionMethodEnabled(_ methodID: UUID) -> Bool {
        guard let entity = try? customizationService.fetchProtectionMethod(id: methodID) else {
            return false
        }
        return entity.isEnabled
    }
    
    /// Toggle protection method enabled status
    func toggleProtectionMethod(_ methodID: UUID) {
        try? customizationService.toggleProtectionMethod(id: methodID)
    }
    
    // MARK: - Legacy Enum-based Methods (DEPRECATED - for backwards compatibility)
    
    /// Check if activity type is enabled (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use isActivityEnabled(_ activityID: UUID) instead")
    func isActivityEnabled(_ activity: SQLActivityType) -> Bool {
        isActivityEnabled(activity.predefinedUUID)
    }
    
    /// Toggle activity (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use toggleActivity(_ activityID: UUID) instead")
    func toggleActivity(_ activity: SQLActivityType) {
        toggleActivity(activity.predefinedUUID)
    }
    
    /// Check if protection method is enabled (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use isProtectionMethodEnabled(_ methodID: UUID) instead")
    func isProtectionMethodEnabled(_ method: SQLProtectionMethod) -> Bool {
        isProtectionMethodEnabled(method.predefinedUUID)
    }
    
    /// Toggle protection method (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use toggleProtectionMethod(_ methodID: UUID) instead")
    func toggleProtectionMethod(_ method: SQLProtectionMethod) {
        toggleProtectionMethod(method.predefinedUUID)
    }
    
    /// Get enabled activities as Set (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use enabledActivityTypes() instead")
    var enabledActivities: Set<SQLActivityType> {
        get {
            Set(
                enabledActivityTypes()
                    .compactMap { entity in
                        SQLActivityType.allCases.first { $0.predefinedUUID == entity.id }
                    }
            )
        }
        set {
            // Update database for each activity
            for activity in SQLActivityType.allCases {
                let shouldBeEnabled = newValue.contains(activity)
                if isActivityEnabled(activity.predefinedUUID) != shouldBeEnabled {
                    toggleActivity(activity.predefinedUUID)
                }
            }
        }
    }
    
    /// Get enabled protection methods as Set (DEPRECATED: enum-based)
    @available(*, deprecated, message: "Use enabledProtectionMethods() instead")
    var enabledProtectionMethodsSet: Set<SQLProtectionMethod> {
        get {
            Set(
                enabledProtectionMethods()
                    .compactMap { entity in
                        SQLProtectionMethod.allCases.first { $0.predefinedUUID == entity.id }
                    }
            )
        }
        set {
            // Update database for each protection method
            for method in SQLProtectionMethod.allCases {
                let shouldBeEnabled = newValue.contains(method)
                if isProtectionMethodEnabled(method.predefinedUUID) != shouldBeEnabled {
                    toggleProtectionMethod(method.predefinedUUID)
                }
            }
        }
    }
}
