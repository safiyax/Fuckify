//
//  ProtectionMethodsSettingsView.swift
//  Fuckify
//
//  Settings view for managing protection methods
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ProtectionMethodsSettings")

extension SQLProtectionMethodEntity: CustomizableItem {}

struct ProtectionMethodsSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var protectionMethods: [SQLProtectionMethodEntity] = []
    
    private let accentColor = Color.green
    
    var body: some View {
        CustomizationSettingsView(
            navigationTitle: "Protection Methods",
            itemTypeName: "Protection Method",
            descriptionText: "Manage protection methods for logging encounters. Built-in methods can be enabled/disabled. Custom methods can be edited or deleted.",
            accentColor: accentColor,
            items: protectionMethods,
            onToggle: toggleMethod,
            onDelete: deleteMethod,
            addSheet: { ProtectionMethodFormView(onSave: loadProtectionMethods) },
            editSheet: { method in
                ProtectionMethodFormView(method: method, onSave: loadProtectionMethods)
            },
            itemRow: { method, toggle in
                ProtectionMethodRow(method: method, onToggle: toggle)
            }
        )
        .onAppear { loadProtectionMethods() }
    }
    
    private func loadProtectionMethods() {
        protectionMethods = settings.allProtectionMethods()
    }
    
    private func toggleMethod(_ method: SQLProtectionMethodEntity) {
        logger.info("Toggling protection method: \(method.id)")
        settings.toggleProtectionMethod(method.id)
        loadProtectionMethods()
    }
    
    private func deleteMethod(_ method: SQLProtectionMethodEntity) {
        logger.info("Deleting protection method: \(method.id)")
        settings.deleteProtectionMethod(method.id)
        loadProtectionMethods()
    }
}

// MARK: - Protection Method Row

private struct ProtectionMethodRow: View {
    let method: SQLProtectionMethodEntity
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: method.icon,
            name: method.name,
            isEnabled: method.isEnabled,
            isBuiltIn: method.isBuiltIn,
            accentColor: .green,
            onToggle: onToggle
        )
    }
}
