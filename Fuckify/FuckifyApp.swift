//
//  FuckifyApp.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SQLiteData

@main
struct FuckifyApp: App {
    @State private var isUnlocked: Bool
    @State private var securitySettings = SecuritySettings.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize SQLite database and prepare dependencies
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
        
        // Initialize lock state based on security settings
        // Start locked if security is enabled
        _isUnlocked = State(initialValue: !SecuritySettings.shared.isSecurityEnabled)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Always render main app in background
                ContentView()
                
                // Show lock screen on top if security is enabled and (not unlocked OR not active)
                if securitySettings.isSecurityEnabled && (!isUnlocked || scenePhase != .active) {
                    LockScreenView(isUnlocked: $isUnlocked)
                        .transition(.identity) // No transition animation
                }
            }
            .animation(nil, value: isUnlocked) // Disable animation for instant appearance
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if securitySettings.isSecurityEnabled {
                    if newPhase != .active {
                        // Lock immediately when not active (app switcher, background, etc.)
                        isUnlocked = false
                    }
                }
            }
        }
    }
}
