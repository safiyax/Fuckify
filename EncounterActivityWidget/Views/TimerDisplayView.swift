//
//  TimerDisplayView.swift
//  EncounterActivityWidget
//
//  Reusable timer display for Live Activity
//

import SwiftUI

struct TimerDisplayView: View {
    let state: EncounterActivityAttributes.ContentState
    let font: Font
    let color: Color
    
    init(state: EncounterActivityAttributes.ContentState, font: Font = .body, color: Color = .primary) {
        self.state = state
        self.font = font
        self.color = color
    }
    
    var body: some View {
        if state.isPaused {
            // Show static time when paused
            Text(formatDuration(state.elapsedActiveTime()))
                .font(font)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .monospacedDigit()
        } else {
            // Show auto-updating timer when running
            Text(effectiveStartTime, style: .timer)
                .font(font)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .monospacedDigit()
        }
    }
    
    private var effectiveStartTime: Date {
        // Adjust start time to account for paused duration
        state.startTime.addingTimeInterval(state.totalPausedDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
