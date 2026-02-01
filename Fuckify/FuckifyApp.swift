//
//  FuckifyApp.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SQLiteData
import UIKit
import UserNotifications

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
    @State private var liveActivityManager = LiveActivityManager.shared
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
        
        // Request notification permissions for 8-hour warnings
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
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
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("togglePauseEncounter"))) { _ in
                Task {
                    await handleTogglePause()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("finishEncounter"))) { _ in
                Task {
                    await handleFinishEncounter()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .encounterAutoSaved)) { notification in
                Task {
                    await handleAutoSavedEncounter(notification)
                }
            }
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
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "coitalcomrade" else { return }
        
        if url.host == "active-encounter" {
            // Show active encounter view
            NotificationCenter.default.post(name: Notification.Name("showActiveEncounter"), object: nil)
        }
    }
    
    // MARK: - Live Activity Handlers
    
    @MainActor
    private func handleTogglePause() async {
        guard let state = liveActivityManager.currentState() else { return }
        
        if state.isPaused {
            await liveActivityManager.resumeEncounter()
        } else {
            await liveActivityManager.pauseEncounter()
        }
    }
    
    @MainActor
    private func handleFinishEncounter() async {
        guard let data = await liveActivityManager.finishEncounter() else { return }
        
        // Create encounter with the tracked data
        await createAndEditEncounter(
            duration: data.duration,
            partnerIDs: data.partnerIDs,
            encounterID: data.encounterID,
            startTime: data.startTime
        )
    }
    
    @MainActor
    private func handleAutoSavedEncounter(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let duration = userInfo["duration"] as? TimeInterval,
              let partnerIDs = userInfo["partnerIDs"] as? [UUID],
              let encounterID = userInfo["encounterID"] as? UUID,
              let startTime = userInfo["startTime"] as? Date else {
            return
        }
        
        await createAndEditEncounter(
            duration: duration,
            partnerIDs: partnerIDs,
            encounterID: encounterID,
            startTime: startTime
        )
    }
    
    @MainActor
    private func createAndEditEncounter(duration: TimeInterval, partnerIDs: [UUID], encounterID: UUID, startTime: Date) async {
        // Import dependencies
        @Dependency(\.encounterService) var encounterService
        
        // Create the encounter
        let draft = SQLEncounter.Draft(
            id: encounterID,
            date: startTime,
            duration: duration,
            location: "",
            notes: "",
            rating: 0,
            reachedOrgasm: false,
            dateAdded: Date()
        )
        
        do {
            _ = try encounterService.create(
                draft,
                partnerIDs: partnerIDs,
                activities: [],
                protectionMethods: []
            )
            
            // Fetch the created encounter to pass to edit form
            if let encounter = try encounterService.fetchByID(encounterID) {
                // Post notification to open edit form
                NotificationCenter.default.post(
                    name: Notification.Name("editEncounter"),
                    object: nil,
                    userInfo: ["encounter": encounter]
                )
            }
        } catch {
            print("Failed to create encounter: \(error)")
        }
    }
}
