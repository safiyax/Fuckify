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
import OSLog
import PostHog

private let logger = Logger(subsystem: "baby.safi.Fuckify", category: "App")

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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var isUnlocked: Bool
    
    // Dependency-injected instances (no more singletons!)
    @State private var securitySettings = SecuritySettings()
    @State private var userProfile = UserProfile()
    @State private var userSettings = UserSettings()
    @State private var liveActivityManager = LiveActivityManager()
    
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
        let tempSecuritySettings = SecuritySettings()
        _isUnlocked = State(initialValue: !tempSecuritySettings.isSecurityEnabled)
        _securitySettings = State(initialValue: tempSecuritySettings)
        
        // Request notification permissions for 8-hour warnings
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        
        let POSTHOG_API_KEY = "phc_3B4gzM4mmgBj8lOIT6cKjQIqdFF3Dwnsca2ekWF0FYV"
        let POSTHOG_HOST = "https://us.i.posthog.com"
        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        config.enableSwizzling = false
//        config.optOut = false
        
        PostHogSDK.shared.setup(config)

        var properties: [String : Any] = [
            "$app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "$app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
        ]
        #if DEBUG
        properties["is_internal_user"] = true
        PostHogSDK.shared.setPersonPropertiesForFlags(properties, reloadFeatureFlags: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                // Show onboarding for first-time users
                OnboardingView()
                    .environment(userProfile)
            } else {
                ZStack {
                    // Always render main app in background
                    ContentView()
                    .environment(securitySettings)
                    .environment(userProfile)
                    .environment(userSettings)
                    .environment(liveActivityManager)
                    .environment(\.appIsLocked, securitySettings.isSecurityEnabled && !isUnlocked)
                    .onShake {
                        // Lock immediately on shake if security is enabled and unlocked
                        if securitySettings.isSecurityEnabled && isUnlocked {
                            logger.info("Shake detected - locking app")
                            isUnlocked = false
                        }
                    }
                
                // Show lock screen on top if security is enabled and not unlocked
                if securitySettings.isSecurityEnabled && !isUnlocked {
                    LockScreenView(isUnlocked: $isUnlocked)
                        .environment(securitySettings)
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("finishEncounter"))) { notification in
                Task {
                    await handleFinishEncounter(notification: notification)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .encounterAutoSaved)) { notification in
                Task {
                    await handleAutoSavedEncounter(notification)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                logger.info("ScenePhase changed: \(String(describing: oldPhase)) -> \(String(describing: newPhase)), isUnlocked: \(isUnlocked)")
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
                        logger.info("Scene inactive - isIAPInProgress: \(iapState.isIAPInProgress)")
                        if !iapState.isIAPInProgress {
                            isUnlocked = false
                            logger.info("Locking app due to inactive scene")
                        } else {
                            logger.info("Skipping lock - IAP purchase in progress")
                        }
                    }
                    
                case .background:
                    // Lock when backgrounded
                    wasInactive = false
                    isUnlocked = false
                    logger.info("Scene backgrounded - locking app")
                    
                @unknown default:
                    // Lock for any unknown future states
                    isUnlocked = false
                }
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
        } else if url.host == "finish-encounter" {
            // Handle finish encounter deep link from Live Activity
            // Format: coitalcomrade://finish-encounter?encounterID=...&startTime=...&duration=...&partnerIDs=...
            Task {
                await handleFinishEncounterDeepLink(url: url)
            }
        }
    }
    
    @MainActor
    private func handleFinishEncounterDeepLink(url: URL) async {
        // Parse URL parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.error("Invalid finish encounter URL - no query items")
            return
        }
        
        // Extract parameters
        guard let encounterIDString = queryItems.first(where: { $0.name == "encounterID" })?.value,
              let encounterID = UUID(uuidString: encounterIDString),
              let startTimeString = queryItems.first(where: { $0.name == "startTime" })?.value,
              let startTimeInterval = TimeInterval(startTimeString),
              let durationString = queryItems.first(where: { $0.name == "duration" })?.value,
              let duration = TimeInterval(durationString),
              let partnerIDsString = queryItems.first(where: { $0.name == "partnerIDs" })?.value else {
            logger.error("Missing required parameters in finish encounter URL")
            return
        }
        
        // Parse partner IDs
        let partnerIDs = partnerIDsString.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        
        logger.info("Parsed finish encounter deep link - encounterID: \(encounterID), duration: \(duration)s, partners: \(partnerIDs.count)")
        
        // End the Live Activity
        _ = await liveActivityManager.finishEncounter()
        
        // Create and edit encounter
        await createAndEditEncounter(
            duration: duration,
            partnerIDs: partnerIDs,
            encounterID: encounterID,
            startTime: startTime
        )
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
    private func handleFinishEncounter(notification: Notification) async {
        logger.info("handleFinishEncounter called")
        
        // Clear LiveActivityManager state (activity was ended by intent)
        liveActivityManager.clearCurrentActivity()
        logger.info("Cleared LiveActivityManager state")
        
        // Check if notification contains encounter data (from LiveActivityIntent)
        if let userInfo = notification.userInfo,
           let duration = userInfo["duration"] as? TimeInterval,
           let partnerIDs = userInfo["partnerIDs"] as? [UUID],
           let encounterID = userInfo["encounterID"] as? UUID,
           let startTime = userInfo["startTime"] as? Date {
            // Data provided by intent - use it directly
            logger.info("Got encounter data from notification - duration: \(duration)s, encounterID: \(encounterID)")
            await createAndEditEncounter(
                duration: duration,
                partnerIDs: partnerIDs,
                encounterID: encounterID,
                startTime: startTime
            )
        } else {
            // Old path - get data from LiveActivityManager
            logger.warning("No userInfo in notification, falling back to LiveActivityManager")
            guard let data = await liveActivityManager.finishEncounter() else { 
                logger.error("LiveActivityManager returned no data")
                return 
            }
            
            logger.info("Got encounter data from LiveActivityManager - duration: \(data.duration)s")
            await createAndEditEncounter(
                duration: data.duration,
                partnerIDs: data.partnerIDs,
                encounterID: data.encounterID,
                startTime: data.startTime
            )
        }
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
        logger.info("createAndEditEncounter called - encounterID: \(encounterID), duration: \(duration)s")
        
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
            logger.info("Creating encounter in database...")
            _ = try encounterService.create(
                draft,
                partnerIDs: partnerIDs,
                activityTypeIDs: [],        // NEW: UUID-based
                protectionMethodIDs: []     // NEW: UUID-based
            )
            logger.info("Encounter created successfully")
            
            // Fetch the created encounter to pass to edit form
            if let encounter = try encounterService.fetchByID(encounterID) {
                logger.info("Fetched encounter, posting editEncounter notification")
                
                // Post notification to open edit form
                NotificationCenter.default.post(
                    name: Notification.Name("editEncounter"),
                    object: nil,
                    userInfo: ["encounter": encounter]
                )
                logger.info("editEncounter notification posted successfully")
            } else {
                logger.error("Failed to fetch encounter after creation")
            }
        } catch {
            logger.error("Failed to create encounter: \(error.localizedDescription)")
        }
    }
}
