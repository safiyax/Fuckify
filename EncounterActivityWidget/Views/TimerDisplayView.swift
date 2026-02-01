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
        Text(timerString)
            .font(font)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .monospacedDigit()
    }
    
    private var timerString: String {
        let elapsed = state.elapsedActiveTime()
        return formatDuration(elapsed)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            // Format: H:MM:SS or HH:MM:SS
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Format: MM:SS
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
