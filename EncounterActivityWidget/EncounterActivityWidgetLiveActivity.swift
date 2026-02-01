//
//  EncounterActivityWidgetLiveActivity.swift
//  EncounterActivityWidget
//
//  Live Activity for encounter tracking
//

import ActivityKit
import WidgetKit
import SwiftUI

struct EncounterActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EncounterActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.accentColor.opacity(0.2))
                .activitySystemActionForegroundColor(Color.accentColor)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - shown when long pressing the Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    TimerDisplayView(
                        state: context.state,
                        font: .title2,
                        color: .accentColor
                    )
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Partner chips in grid (max 4 slots: 3 partners + overflow)
                        PartnerGridView(partners: context.attributes.partners)
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Pause/Resume button
                            Button(intent: TogglePauseIntent(encounterID: context.attributes.encounterID)) {
                                HStack(spacing: 4) {
                                    Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                        .font(.caption)
                                    Text(context.state.isPaused ? "Resume" : "Pause")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            
                            // Finish button
                            Button(intent: FinishEncounterIntent(encounterID: context.attributes.encounterID)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                    Text("Finish")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
                
            } compactLeading: {
                // Compact leading - just the icon
                Image(systemName: "bolt.heart.fill")
                    .foregroundColor(.accentColor)
                
            } compactTrailing: {
                // Compact trailing - empty (icon shows on leading)
                EmptyView()
                
            } minimal: {
                // Minimal - icon on leading, timer on trailing
                HStack {
                    Image(systemName: "bolt.heart.fill")
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    TimerDisplayView(
                        state: context.state,
                        font: .caption2,
                        color: .accentColor
                    )
                }
            }
            .widgetURL(URL(string: "coitalcomrade://active-encounter"))
            .keylineTint(Color.accentColor)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<EncounterActivityAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "bolt.heart.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text("Active Encounter")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Partners
                Text(partnerNames)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timer
            TimerDisplayView(
                state: context.state,
                font: .title3,
                color: .accentColor
            )
        }
        .padding()
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

import AppIntents

struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription = IntentDescription("Pause or resume the encounter timer")
    
    @Parameter(title: "Encounter ID")
    var encounterID: UUID
    
    init() {
        self.encounterID = UUID()
    }
    
    init(encounterID: UUID) {
        self.encounterID = encounterID
    }
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the main app via notification
        NotificationCenter.default.post(
            name: Notification.Name("togglePauseEncounter"),
            object: nil,
            userInfo: ["encounterID": encounterID]
        )
        return .result()
    }
}

struct FinishEncounterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish Encounter"
    static var description: IntentDescription = IntentDescription("Finish the current encounter")
    
    @Parameter(title: "Encounter ID")
    var encounterID: UUID
    
    init() {
        self.encounterID = UUID()
    }
    
    init(encounterID: UUID) {
        self.encounterID = encounterID
    }
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the main app via notification
        NotificationCenter.default.post(
            name: Notification.Name("finishEncounter"),
            object: nil,
            userInfo: ["encounterID": encounterID]
        )
        return .result()
    }
}

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
