//
//  EncounterActivityWidgetLiveActivity.swift
//  EncounterActivityWidget
//
//  Live Activity for encounter tracking
//

import ActivityKit
import WidgetKit
import SwiftUI
import OSLog
import AppIntents

private let logger = Logger(subsystem: "baby.safi.Fuckify.widget", category: "LiveActivity")

// Helper function to format partner names
private func formatPartnerNames(_ partners: [PartnerData]) -> String {
    let names = partners.map(\.name)
    if names.count <= 2 {
        return names.joined(separator: " & ")
    } else if names.count == 3 {
        return "\(names[0]), \(names[1]) & \(names[2])"
    } else {
        return "\(names[0]), \(names[1]) & \(names.count - 2) more"
    }
}

struct EncounterActivityWidgetLiveActivity: Widget {
    
    private func effectiveStartTime(_ state: EncounterActivityAttributes.ContentState) -> Date {
        return state.startTime.addingTimeInterval(state.totalPausedDuration)
    }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EncounterActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenView(context: context)
                .activityBackgroundTint(Color.accent.opacity(0.2))
                .activitySystemActionForegroundColor(Color.accent)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation - matches Lock Screen layout
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Button(intent: TogglePauseIntent()) {
                            Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .tint(.accent)
                        
                        Link(destination: URL(string: "coitalcomrade://finish-encounter?encounterID=\(context.attributes.encounterID)&startTime=\(context.state.startTime.timeIntervalSince1970)&duration=\(context.state.elapsedActiveTime())&partnerIDs=\(context.attributes.partners.map(\.id.uuidString).joined(separator: ","))")!) {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .tint(.primary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                        TimerText(state: context.state)
                            .font(.largeTitle)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(formatPartnerNames(context.attributes.partners))
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.accent)
                }
                
            } compactLeading: {
                // Compact leading - icon only
                Image(systemName: "bolt.heart.fill")
                    .foregroundColor(.accent)
                
            } compactTrailing: {
                // Compact trailing - timer only
                TimerText(state: context.state)
                    .foregroundColor(context.state.isPaused ? .gray : .accent)
                
            } minimal: {
                // Minimal - just icon
                Image(systemName: "bolt.heart.fill")
                    .foregroundColor(.accent)
            }
            .widgetURL(URL(string: "coitalcomrade://active-encounter"))
            .keylineTint(Color.accent)
        }
    }
}

// MARK: - Timer Text View

struct TimerText: View {
    let state: EncounterActivityAttributes.ContentState
    
    var body: some View {
        Text(state.isPaused ? formatElapsedTime(state.elapsedActiveTime()) : maxStringFor(state.elapsedActiveTime()))
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .leading) {
                if state.isPaused {
                    Text(formatElapsedTime(state.elapsedActiveTime()))
                        .monospacedDigit()
                        .foregroundColor(.gray)
                } else {
                    Text(effectiveStartTime, style: .timer)
                        .monospacedDigit()
                        .foregroundColor(.accent)
                }
            }
    }
    
    
    private var effectiveStartTime: Date {
        state.startTime.addingTimeInterval(state.totalPausedDuration)
    }
    
    private func maxStringFor(_ time: TimeInterval) -> String {
        if time < 600 { // 9:99
            return "0:00"
        }

        if time < 3600 { // 59:59
            return "00:00"
        }

        if time < 36000 { // 9:59:59
            return "0:00:00"
        }

        return "00:00:00"// 99:59:59
    }
    
    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
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

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<EncounterActivityAttributes>
    
    var body: some View {
        
        HStack(spacing: 8) {
            Button(intent: TogglePauseIntent()) {
                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(.accent)
            
            Link(destination: URL(string: "coitalcomrade://finish-encounter?encounterID=\(context.attributes.encounterID)&startTime=\(context.state.startTime.timeIntervalSince1970)&duration=\(context.state.elapsedActiveTime())&partnerIDs=\(context.attributes.partners.map(\.id.uuidString).joined(separator: ","))")!) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(.primary)
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(partnerNames)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
                TimerText(state: context.state)
                    .font(.largeTitle)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var partnerNames: String {
        let names = context.attributes.partners.map(\.name)
        if names.count <= 2 {
            return names.joined(separator: " & ")
        } else if names.count == 3 {
            return "\(names[0]), \(names[1]) & \(names[2])"
        } else {
            return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
    }
}

// MARK: - Partner Grid View

struct PartnerGridView: View {
    let partners: [PartnerData]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(displayedPartners) { partner in
                LiveActivityPartnerChipView(partner: partner)
            }
            
            if overflowCount > 0 {
                OverflowPartnerChip(count: overflowCount)
            }
        }
    }
    
    private var displayedPartners: [PartnerData] {
        Array(partners.prefix(3))
    }
    
    private var overflowCount: Int {
        max(0, partners.count - 3)
    }
}

// MARK: - App Intents for Buttons
// NOTE: Intent implementations are in Fuckify/Shared/LiveActivity/LiveActivityIntents.swift
// That file must be added to BOTH the main app target AND widget extension target

// MARK: - Previews

#Preview("Notification - Running", as: .content, using: EncounterActivityAttributes.preview) {
   EncounterActivityWidgetLiveActivity()
} contentStates: {
    EncounterActivityAttributes.ContentState.running
}

#Preview("Notification - Paused", as: .content, using: EncounterActivityAttributes.preview) {
   EncounterActivityWidgetLiveActivity()
} contentStates: {
    EncounterActivityAttributes.ContentState.paused
}
