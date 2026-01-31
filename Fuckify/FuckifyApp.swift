//
//  FuckifyApp.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SQLiteData
import UIKit

// MARK: - Shake Detection

extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

struct ShakeDetectorModifier: ViewModifier {
    let onShake: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                onShake()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetectorModifier(onShake: action))
    }
}

// MARK: - Environment Key for App Lock State

private struct AppIsLockedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var appIsLocked: Bool {
        get { self[AppIsLockedKey.self] }
        set { self[AppIsLockedKey.self] = newValue }
    }
}

// MARK: - View Modifier to Dismiss Sheets When App Locks

struct DismissOnAppLockModifier: ViewModifier {
    @Environment(\.appIsLocked) private var appIsLocked
    @Environment(\.dismiss) private var dismiss
    
    func body(content: Content) -> some View {
        content
            .onChange(of: appIsLocked) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
    }
}

extension View {
    func dismissOnAppLock() -> some View {
        modifier(DismissOnAppLockModifier())
    }
}

@main
struct FuckifyApp: App {
    @State private var isUnlocked: Bool
    @State private var securitySettings = SecuritySettings.shared
    @StateObject private var iapState = IAPStateManager.shared
    @State private var wasInactive = false
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
                    .environment(\.appIsLocked, securitySettings.isSecurityEnabled && !isUnlocked)
                    .onShake {
                        // Lock immediately on shake if security is enabled and unlocked
                        if securitySettings.isSecurityEnabled && isUnlocked {
                            print("📳 [Shake] Locking app")
                            isUnlocked = false
                        }
                    }
                
                // Show lock screen on top if security is enabled and not unlocked
                if securitySettings.isSecurityEnabled && !isUnlocked {
                    LockScreenView(isUnlocked: $isUnlocked)
                        .transition(.identity) // No transition animation
                        .zIndex(999) // Ensure it's above everything
                }
            }
            .animation(nil, value: isUnlocked) // Disable animation for instant appearance
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("📱 [ScenePhase] \(oldPhase) -> \(newPhase), isUnlocked: \(isUnlocked)")
                guard securitySettings.isSecurityEnabled else { return }
                
                switch newPhase {
                case .active:
                    // Clear the inactive flag when we're truly active
                    wasInactive = false
                    
                case .inactive:
                    // Only lock if we're currently unlocked
                    // This prevents locking an already-locked app
                    if isUnlocked {
                        // Mark that we've been inactive
                        wasInactive = true
                        
                        // Lock immediately when inactive, UNLESS an IAP purchase is in progress
                        print("🔒 [FuckifyApp] .inactive - isIAPInProgress: \(iapState.isIAPInProgress)")
                        if !iapState.isIAPInProgress {
                            isUnlocked = false
                            print("🔒 [FuckifyApp] Locking app")
                        } else {
                            print("🛒 [FuckifyApp] Skipping lock - IAP in progress")
                        }
                    }
                    
                case .background:
                    // Lock when backgrounded
                    wasInactive = false
                    isUnlocked = false
                    print("🔒 [FuckifyApp] .background - locking app")
                    
                @unknown default:
                    // Lock for any unknown future states
                    isUnlocked = false
                }
            }
        }
    }
}
