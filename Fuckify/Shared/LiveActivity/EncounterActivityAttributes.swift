//
//  EncounterActivityAttributes.swift
//  Fuckify
//
//  Live Activity attributes for encounter tracking
//

import Foundation
import ActivityKit

/// Attributes for the encounter Live Activity
struct EncounterActivityAttributes: ActivityAttributes {
    
    /// Dynamic state that can be updated during the Live Activity
    public struct ContentState: Codable, Hashable {
        /// When the encounter started
        var startTime: Date
        
        /// Whether the timer is currently paused
        var isPaused: Bool
        
        /// When the timer was paused (nil if not paused or never paused)
        var pausedAt: Date?
        
        /// Total accumulated paused time in seconds
        var totalPausedDuration: TimeInterval
        
        /// Initialize with default running state
        init(startTime: Date = Date(), isPaused: Bool = false, pausedAt: Date? = nil, totalPausedDuration: TimeInterval = 0) {
            self.startTime = startTime
            self.isPaused = isPaused
            self.pausedAt = pausedAt
            self.totalPausedDuration = totalPausedDuration
        }
        
        /// Calculate current elapsed active time (excluding paused duration)
        func elapsedActiveTime(currentTime: Date = Date()) -> TimeInterval {
            let totalElapsed = currentTime.timeIntervalSince(startTime)
            
            if isPaused, let pausedAt = pausedAt {
                // Currently paused - calculate time up to pause, minus previous pauses
                let timeUntilPause = pausedAt.timeIntervalSince(startTime)
                return timeUntilPause - totalPausedDuration
            } else {
                // Running - total elapsed minus all paused time
                return totalElapsed - totalPausedDuration
            }
        }
    }
    
    // Fixed attributes that don't change during the activity
    
    /// Partners involved in this encounter
    var partners: [PartnerData]
    
    /// Unique identifier for this encounter session
    var encounterID: UUID
}

// MARK: - Preview Helpers

#if DEBUG
extension EncounterActivityAttributes {
    static var preview: EncounterActivityAttributes {
        EncounterActivityAttributes(
            partners: [
                PartnerData(id: UUID(), name: "Alex", avatarColor: "blue"),
                PartnerData(id: UUID(), name: "Sam", avatarColor: "pink")
            ],
            encounterID: UUID()
        )
    }
}

extension EncounterActivityAttributes.ContentState {
    static var running: EncounterActivityAttributes.ContentState {
        EncounterActivityAttributes.ContentState(
            startTime: Date().addingTimeInterval(-900), // Started 15 minutes ago
            isPaused: false
        )
    }
    
    static var paused: EncounterActivityAttributes.ContentState {
        EncounterActivityAttributes.ContentState(
            startTime: Date().addingTimeInterval(-1800), // Started 30 minutes ago
            isPaused: true,
            pausedAt: Date().addingTimeInterval(-300), // Paused 5 minutes ago
            totalPausedDuration: 300 // 5 minutes of pause
        )
    }
}
#endif
