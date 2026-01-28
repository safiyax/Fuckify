//
//  SettingsConfig.swift
//  Fuckify
//
//  Configuration file to control which settings options are visible
//

import Foundation

struct SettingsConfig {
    static let shared = SettingsConfig()
    
    // MARK: - Personalization Section
    
    /// Show/hide the App Icon picker
    let showAppIconPicker = false
    
    /// Show/hide Activities customization
    let showActivities = true
    
    /// Show/hide Protection Methods customization
    let showProtectionMethods = true
    
    // MARK: - Data Section
    
    /// Show/hide Import & Export
    let showImportExport = true
    
    /// Show/hide Delete Data
    let showDeleteData = true
    
    // MARK: - More Section
    
    /// Show/hide About
    let showAbout = true
    
    /// Show/hide Support (Buy Me a Coffee)
    let showSupport = true
    
    /// Show/hide Experiments
    let showExperiments = false
    
    // MARK: - Section Visibility Helpers
    
    /// Whether to show the entire Personalization section
    var showPersonalizationSection: Bool {
        showAppIconPicker || showActivities || showProtectionMethods
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
