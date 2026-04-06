//
//  LiveActivityIntents.swift
//  Fuckify
//
//  App Intents for Live Activity interactions
//  NOTE: Must be added to BOTH app and widget extension targets
//

import AppIntents
import ActivityKit

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "LiveActivityIntents")

// MARK: - Toggle Pause Intent

struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription = IntentDescription("Pause or resume the encounter timer")
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        logger.info("TogglePauseIntent.perform() called from app process")
        
        let activities = Activity<EncounterActivityAttributes>.activities
        logger.info("Found \(activities.count) active activities")
        
        // Access ActivityKit directly to get all active encounter activities
        for activity in activities {
            let currentState = activity.content.state
            logger.info("Activity state - isPaused: \(currentState.isPaused)")
            
            // Toggle pause state
            if currentState.isPaused {
                // Resume: calculate paused duration and update state
                guard let pausedAt = currentState.pausedAt else { 
                    logger.warning("Activity is paused but pausedAt is nil")
                    continue 
                }
                let pauseDuration = Date().timeIntervalSince(pausedAt)
                
                let newState = EncounterActivityAttributes.ContentState(
                    startTime: currentState.startTime,
                    isPaused: false,
                    pausedAt: nil,
                    totalPausedDuration: currentState.totalPausedDuration + pauseDuration
                )
                
                logger.info("Resuming activity - pauseDuration: \(pauseDuration)s")
                await activity.update(.init(state: newState, staleDate: nil))
                logger.info("Activity resumed successfully")
            } else {
                // Pause: record pause time
                let newState = EncounterActivityAttributes.ContentState(
                    startTime: currentState.startTime,
                    isPaused: true,
                    pausedAt: Date(),
                    totalPausedDuration: currentState.totalPausedDuration
                )
                
                logger.info("Pausing activity")
                await activity.update(.init(state: newState, staleDate: nil))
                logger.info("Activity paused successfully")
            }
        }
        
        logger.info("TogglePauseIntent.perform() completed")
        return .result()
    }
}

// MARK: - Finish Encounter Intent

struct FinishEncounterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish Encounter"
    static var description: IntentDescription = IntentDescription("Finish the current encounter")
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        logger.info("FinishEncounterIntent.perform() called from app process")
        
        let activities = Activity<EncounterActivityAttributes>.activities
        logger.info("Found \(activities.count) active activities to end")
        
        // Collect encounter data before ending activities
        var encounterData: (duration: TimeInterval, partnerIDs: [UUID], encounterID: UUID, startTime: Date)?
        
        // End all active encounter Live Activities
        for activity in activities {
            let state = activity.content.state
            let attributes = activity.attributes
            
            // Calculate final duration
            let duration = state.elapsedActiveTime()
            
            // Store data for the first activity (should only be one)
            if encounterData == nil {
                encounterData = (
                    duration: duration,
                    partnerIDs: attributes.partners.map(\.id),
                    encounterID: attributes.encounterID,
                    startTime: state.startTime
                )
            }
            
            logger.info("Ending activity - encounterID: \(attributes.encounterID), duration: \(duration)s")
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            logger.info("Activity ended successfully")
        }
        
        // Trigger the finish flow with encounter data
        if let data = encounterData {
            logger.info("Triggering finish encounter UI flow via notification with data")
            logger.info("Posting notification - duration: \(data.duration)s, encounterID: \(data.encounterID), partnerCount: \(data.partnerIDs.count)")
            
            // Post notification first (for the app to handle when it opens)
            DispatchQueue.main.async {
                logger.info("Posting finishEncounter notification on main thread")
                NotificationCenter.default.post(
                    name: Notification.Name("finishEncounter"),
                    object: nil,
                    userInfo: [
                        "duration": data.duration,
                        "partnerIDs": data.partnerIDs,
                        "encounterID": data.encounterID,
                        "startTime": data.startTime
                    ]
                )
                logger.info("finishEncounter notification posted successfully")
            }
        } else {
            logger.warning("No encounter data found - cannot trigger finish flow")
        }
        
        return .result()
    }
}
