//
//  LiveActivityIntentsProvider.swift
//  EncounterActivityWidget
//
//  App Shortcuts provider to register Live Activity intents
//

import AppIntents

struct LiveActivityIntentsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TogglePauseIntent(),
            phrases: [
                "Toggle pause in \(.applicationName)",
                "Pause encounter in \(.applicationName)"
            ],
            shortTitle: "Toggle Pause",
            systemImageName: "pause.circle"
        )
        
        AppShortcut(
            intent: FinishEncounterIntent(),
            phrases: [
                "Finish encounter in \(.applicationName)",
                "End tracking in \(.applicationName)"
            ],
            shortTitle: "Finish Encounter",
            systemImageName: "checkmark.circle"
        )
    }
}
