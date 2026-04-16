//
//  SettingsConfig.swift
//  Fuckify
//
//  Configuration file to control which settings options are visible
//  Uses FeatureFlagsManager to fetch configuration from PostHog with fallback to defaults
//

import Foundation

@MainActor
@Observable
class SettingsConfig {
    static let shared = SettingsConfig()
    
    // MARK: - Published Properties
    
    // Personalization Section
    var showAppIconPicker: Bool
    var showActivities: Bool
    var showProtectionMethods: Bool
    var showPositions: Bool
    var showSecurity: Bool
    
    // Data Section
    var showImportExport: Bool
    var showDeleteData: Bool
    
    // More Section
    var showAbout: Bool
    var showSupport: Bool
    var showExperiments: Bool
    
    // Debug Menu
    var showDebugMenu: Bool {
        FeatureFlagsManager.shared.isDebugMenuEnabled
    }
    
    // MARK: - Private Properties
    
    private let flagsManager = FeatureFlagsManager.shared
    
    // Hardcoded fallback defaults
    private let defaults = SettingsFlagsPayload(
        personalization: .init(
            showAppIconPicker: false,
            showActivities: true,
            showProtectionMethods: true,
            showPositions: true,
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
        self.showPositions = defaults.personalization.showPositions
        self.showSecurity = defaults.personalization.showSecurity
        
        self.showImportExport = defaults.data.showImportExport
        self.showDeleteData = defaults.data.showDeleteData
        
        self.showAbout = defaults.more.showAbout
        self.showSupport = defaults.more.showSupport
        self.showExperiments = defaults.more.showExperiments
        
        // Apply flags if already loaded (e.g., on subsequent initializations)
        refreshFromFlags()
    }
    
    // MARK: - Public Methods
    
    /// Refresh settings from feature flags manager
    func refreshFromFlags() {
        if let payload = flagsManager.settingsFlags {
            applyPayload(payload)
        }
    }
    
    // MARK: - Private Methods
    
    private func applyPayload(_ payload: SettingsFlagsPayload) {
        // Personalization
        showAppIconPicker = payload.personalization.showAppIconPicker
        showActivities = payload.personalization.showActivities
        showProtectionMethods = payload.personalization.showProtectionMethods
        showPositions = payload.personalization.showPositions
        showSecurity = payload.personalization.showSecurity
        
        // Data
        showImportExport = payload.data.showImportExport
        showDeleteData = payload.data.showDeleteData
        
        // More
        showAbout = payload.more.showAbout
        showSupport = payload.more.showSupport
        showExperiments = payload.more.showExperiments
    }
    
    // MARK: - Section Visibility Helpers
    
    /// Whether to show the entire Personalization section
    var showPersonalizationSection: Bool {
        showAppIconPicker || showActivities || showProtectionMethods || showPositions || showSecurity
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
