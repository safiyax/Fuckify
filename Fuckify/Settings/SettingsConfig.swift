//
//  SettingsConfig.swift
//  Fuckify
//
//  Configuration file to control which settings options are visible
//  Fetches configuration from PostHog feature flags with fallback to defaults
//

import Foundation
import PostHog

// MARK: - Models for JSON Payload

struct SettingsFlagsPayload: Codable {
    let personalization: PersonalizationFlags
    let data: DataFlags
    let more: MoreFlags
    
    struct PersonalizationFlags: Codable {
        let showAppIconPicker: Bool
        let showActivities: Bool
        let showProtectionMethods: Bool
        let showSecurity: Bool
        
        enum CodingKeys: String, CodingKey {
            case showAppIconPicker = "show_app_icon_picker"
            case showActivities = "show_activities"
            case showProtectionMethods = "show_protection_methods"
            case showSecurity = "show_security"
        }
    }
    
    struct DataFlags: Codable {
        let showImportExport: Bool
        let showDeleteData: Bool
        
        enum CodingKeys: String, CodingKey {
            case showImportExport = "show_import_export"
            case showDeleteData = "show_delete_data"
        }
    }
    
    struct MoreFlags: Codable {
        let showAbout: Bool
        let showSupport: Bool
        let showExperiments: Bool
        
        enum CodingKeys: String, CodingKey {
            case showAbout = "show_about"
            case showSupport = "show_support"
            case showExperiments = "show_experiments"
        }
    }
}

// MARK: - Settings Configuration

@MainActor
@Observable
class SettingsConfig {
    static let shared = SettingsConfig()
    
    // MARK: - Published Properties
    
    // Personalization Section
    var showAppIconPicker: Bool
    var showActivities: Bool
    var showProtectionMethods: Bool
    var showSecurity: Bool
    
    // Data Section
    var showImportExport: Bool
    var showDeleteData: Bool
    
    // More Section
    var showAbout: Bool
    var showSupport: Bool
    var showExperiments: Bool
    
    // Debug Menu
    var showDebugMenu: Bool
    
    // MARK: - Private Properties
    
    private let flagName = "CCSettingsFlags"
    private let debugFlagName = "CCDebugMenu"
    private let versionKey = "last_flags_version"
    
    // Hardcoded fallback defaults
    private let defaults = SettingsFlagsPayload(
        personalization: .init(
            showAppIconPicker: false,
            showActivities: true,
            showProtectionMethods: true,
            showSecurity: true
        ),
        data: .init(
            showImportExport: true,
            showDeleteData: true
        ),
        more: .init(
            showAbout: true,
            showSupport: false,
            showExperiments: false
        )
    )
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with defaults first
        self.showAppIconPicker = defaults.personalization.showAppIconPicker
        self.showActivities = defaults.personalization.showActivities
        self.showProtectionMethods = defaults.personalization.showProtectionMethods
        self.showSecurity = defaults.personalization.showSecurity
        
        self.showImportExport = defaults.data.showImportExport
        self.showDeleteData = defaults.data.showDeleteData
        
        self.showAbout = defaults.more.showAbout
        self.showSupport = defaults.more.showSupport
        self.showExperiments = defaults.more.showExperiments
        
        self.showDebugMenu = false
        
        // Load from PostHog on init
        Task {
            await loadFlags()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load flags from PostHog
    /// In production: Only reloads if app version has changed
    /// In debug: Reloads on every app launch
    func loadFlags() async {
        let currentVersion = getCurrentAppVersion()
        let lastVersion = UserDefaults.standard.string(forKey: versionKey)
        
        // Always check debug menu flag first
        let isDebugMode = PostHogSDK.shared.isFeatureEnabled(debugFlagName)
        showDebugMenu = isDebugMode
        
        // In debug mode, always reload. Otherwise, only reload if version changed
        let shouldReload = isDebugMode || lastVersion != currentVersion
        
        guard shouldReload else {
            return
        }
        
        // Fetch settings flags
        if let payload = getSettingsFlagsPayload() {
            applyPayload(payload)
        }
        
        // Save current version (only matters in production mode)
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }
    
    /// Force reload flags (for debug menu)
    func forceReloadFlags() async {
        PostHogSDK.shared.reloadFeatureFlags()
        
        // Small delay to let PostHog refresh
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if let payload = getSettingsFlagsPayload() {
            applyPayload(payload)
        }
        
        showDebugMenu = PostHogSDK.shared.isFeatureEnabled(debugFlagName)
    }
    
    // MARK: - Private Methods
    
    private func getSettingsFlagsPayload() -> SettingsFlagsPayload? {
        // Use getFeatureFlagResult to properly track feature flag usage
        let result = PostHogSDK.shared.getFeatureFlagResult(flagName)
        
        guard let payloadJson = result?.payload else {
            return nil
        }
        
        // PostHog returns JSON as [String: Any], convert to Data then decode
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadJson),
              let payload = try? JSONDecoder().decode(SettingsFlagsPayload.self, from: jsonData) else {
            return nil
        }
        
        return payload
    }
    
    private func applyPayload(_ payload: SettingsFlagsPayload) {
        // Personalization
        showAppIconPicker = payload.personalization.showAppIconPicker
        showActivities = payload.personalization.showActivities
        showProtectionMethods = payload.personalization.showProtectionMethods
        showSecurity = payload.personalization.showSecurity
        
        // Data
        showImportExport = payload.data.showImportExport
        showDeleteData = payload.data.showDeleteData
        
        // More
        showAbout = payload.more.showAbout
        showSupport = payload.more.showSupport
        showExperiments = payload.more.showExperiments
    }
    
    private func getCurrentAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version).\(build)"
    }
    
    // MARK: - Section Visibility Helpers
    
    /// Whether to show the entire Personalization section
    var showPersonalizationSection: Bool {
        showAppIconPicker || showActivities || showProtectionMethods || showSecurity
    }
    
    /// Whether to show the entire Data section
    var showDataSection: Bool {
        showImportExport || showDeleteData
    }
    
    /// Whether to show the entire More section
    var showMoreSection: Bool {
        showAbout || showSupport || showExperiments
    }
}
