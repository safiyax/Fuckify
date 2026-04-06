//
//  LiveActivityManager.swift
//  Fuckify
//
//  Manages Live Activity lifecycle for encounter tracking
//

import Foundation
import ActivityKit
import SwiftUI
import UserNotifications

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "LiveActivity")

/// Manages the encounter tracking Live Activity
@MainActor
@Observable
class LiveActivityManager {
    // Removed singleton - inject via environment instead
    
    // MARK: - Properties
    
    /// Current active Live Activity
    private(set) var currentActivity: Activity<EncounterActivityAttributes>?
    
    /// Whether a Live Activity is currently running
    var isActive: Bool {
        currentActivity != nil
    }
    
    /// Current encounter ID (if active)
    var currentEncounterID: UUID? {
        currentActivity?.attributes.encounterID
    }
    
    /// Current partners (if active)
    var currentPartners: [PartnerData]? {
        currentActivity?.attributes.partners
    }
    
    /// Timer for 8-hour auto-save
    private var autoSaveTimer: Timer?
    
    /// Warning timer for 7h 55m warning
    private var warningTimer: Timer?
    
    // MARK: - Constants
    
    private let maxDuration: TimeInterval = 8 * 60 * 60 // 8 hours
    private let warningThreshold: TimeInterval = 7 * 60 * 60 + 55 * 60 // 7h 55m
    
    init() {
        // Monitor for existing activities on app launch
        Task {
            await checkForExistingActivity()
        }
    }
    
    // MARK: - Start Encounter
    
    /// Start a new encounter tracking session
    /// - Parameter partners: Partners involved in this encounter
    /// - Returns: True if successfully started, false otherwise
    @discardableResult
    func startEncounter(partners: [SQLPartner]) async -> Bool {
        guard !partners.isEmpty else {
            logger.error("Cannot start encounter with no partners")
            return false
        }
        
        // Check if already active
        if isActive {
            logger.warning("Live Activity already active")
            return false
        }
        
        // Convert partners to PartnerData
        let partnerData = partners.map { PartnerData(from: $0) }
        
        let attributes = EncounterActivityAttributes(
            partners: partnerData,
            encounterID: UUID()
        )
        
        let initialState = EncounterActivityAttributes.ContentState(
            startTime: Date(),
            isPaused: false
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            currentActivity = activity
            logger.info("Live Activity started: \(activity.id)")
            
            // Schedule auto-save and warning timers
            scheduleTimers()
            
            return true
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Pause/Resume
    
    /// Pause the current encounter timer
    func pauseEncounter() async {
        guard let activity = currentActivity else {
            logger.warning("No active Live Activity to pause")
            return
        }
        
        let currentState = activity.content.state
        
        // Don't pause if already paused
        guard !currentState.isPaused else {
            logger.warning("Live Activity already paused")
            return
        }
        
        let newState = EncounterActivityAttributes.ContentState(
            startTime: currentState.startTime,
            isPaused: true,
            pausedAt: Date(),
            totalPausedDuration: currentState.totalPausedDuration
        )
        
        await updateActivity(state: newState)
        logger.info("Live Activity paused")
    }
    
    /// Resume the current encounter timer
    func resumeEncounter() async {
        guard let activity = currentActivity else {
            logger.warning("No active Live Activity to resume")
            return
        }
        
        let currentState = activity.content.state
        
        // Don't resume if not paused
        guard currentState.isPaused, let pausedAt = currentState.pausedAt else {
            logger.warning("Live Activity not paused")
            return
        }
        
        // Calculate how long we were paused for
        let pauseDuration = Date().timeIntervalSince(pausedAt)
        
        let newState = EncounterActivityAttributes.ContentState(
            startTime: currentState.startTime,
            isPaused: false,
            pausedAt: nil,
            totalPausedDuration: currentState.totalPausedDuration + pauseDuration
        )
        
        await updateActivity(state: newState)
        logger.info("Live Activity resumed (paused for \(pauseDuration)s)")
    }
    
    // MARK: - Finish Encounter
    
    /// Finish the encounter and return the data
    /// - Returns: Tuple of (duration, partnerIDs, encounterID) or nil if no active encounter
    func finishEncounter() async -> (duration: TimeInterval, partnerIDs: [UUID], encounterID: UUID, startTime: Date)? {
        guard let activity = currentActivity else {
            logger.warning("No active Live Activity to finish")
            return nil
        }
        
        let state = activity.content.state
        let attributes = activity.attributes
        
        // Calculate final duration
        let duration = state.elapsedActiveTime()
        let partnerIDs = attributes.partners.map(\.id)
        let encounterID = attributes.encounterID
        let startTime = state.startTime
        
        // End the Live Activity
        await activity.end(nil, dismissalPolicy: .immediate)
        
        currentActivity = nil
        cancelTimers()
        
        logger.info("Live Activity finished - Duration: \(duration)s, Partners: \(partnerIDs.count)")
        
        return (duration, partnerIDs, encounterID, startTime)
    }
    
    /// Cancel the encounter without saving
    func cancelEncounter() async {
        guard let activity = currentActivity else {
            logger.warning("No active Live Activity to cancel")
            return
        }
        
        await activity.end(nil, dismissalPolicy: .immediate)
        
        currentActivity = nil
        cancelTimers()
        
        logger.info("Live Activity cancelled")
    }
    
    // MARK: - Auto-Save (8 Hour Limit)
    
    private func scheduleTimers() {
        cancelTimers() // Clear any existing timers
        
        // Schedule warning timer (7h 55m)
        warningTimer = Timer.scheduledTimer(withTimeInterval: warningThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.showWarning()
            }
        }
        
        // Schedule auto-save timer (8h)
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.autoSaveEncounter()
            }
        }
        
        logger.info("Scheduled auto-save timers")
    }
    
    private func cancelTimers() {
        warningTimer?.invalidate()
        warningTimer = nil
        
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func showWarning() async {
        logger.warning("Approaching 8-hour limit")
        
        // Post notification
        let content = UNMutableNotificationContent()
        content.title = "Encounter Nearing Limit"
        content.body = "Your encounter will be auto-saved in 5 minutes (8 hour limit)."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "encounter-warning-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to show warning notification: \(error.localizedDescription)")
        }
    }
    
    private func autoSaveEncounter() async {
        logger.info("Auto-saving encounter (8-hour limit reached)")
        
        guard let data = await finishEncounter() else {
            return
        }
        
        // Post notification to tell user
        let content = UNMutableNotificationContent()
        content.title = "Encounter Auto-Saved"
        content.body = "Your encounter was automatically saved after 8 hours. Tap to add details."
        content.sound = .default
        content.userInfo = ["encounterID": data.encounterID.uuidString, "action": "edit"]
        
        let request = UNNotificationRequest(
            identifier: "encounter-autosave-\(data.encounterID.uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to show auto-save notification: \(error.localizedDescription)")
        }
        
        // Trigger app-level save (will be handled by the app)
        NotificationCenter.default.post(
            name: .encounterAutoSaved,
            object: nil,
            userInfo: [
                "duration": data.duration,
                "partnerIDs": data.partnerIDs,
                "encounterID": data.encounterID,
                "startTime": data.startTime
            ]
        )
    }
    
    // MARK: - Helpers
    
    private func updateActivity(state: EncounterActivityAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        
        await activity.update(.init(state: state, staleDate: nil))
    }
    
    /// Check for existing Live Activities on app launch
    private func checkForExistingActivity() async {
        let activities = Activity<EncounterActivityAttributes>.activities
        
        if let activity = activities.first {
            currentActivity = activity
            logger.info("Found existing Live Activity: \(activity.id)")
            
            // Reschedule timers based on elapsed time
            let elapsed = activity.content.state.elapsedActiveTime()
            let remaining = maxDuration - elapsed
            
            if remaining > 0 {
                scheduleTimers()
            } else {
                // Already past limit, auto-save immediately
                await autoSaveEncounter()
            }
        }
    }
    
    /// Get current elapsed time for UI display
    func currentElapsedTime() -> TimeInterval? {
        guard let activity = currentActivity else { return nil }
        return activity.content.state.elapsedActiveTime()
    }
    
    /// Get current state (for UI binding)
    func currentState() -> EncounterActivityAttributes.ContentState? {
        currentActivity?.content.state
    }
    
    /// Clear the current activity reference (called when activity is ended externally)
    func clearCurrentActivity() {
        currentActivity = nil
        cancelTimers()
        logger.info("Cleared current activity reference")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let encounterAutoSaved = Notification.Name("encounterAutoSaved")
}
