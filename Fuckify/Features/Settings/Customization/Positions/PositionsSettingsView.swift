//
//  PositionsSettingsView.swift
//  Fuckify
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionsSettings")

extension SQLPositionType: CustomizableItem {}

struct PositionsSettingsView: View {
    @State private var positions: [SQLPositionType] = []
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    private let service = PositionTypeService()
    private let accentColor = Color.orange

    var body: some View {
        CustomizationSettingsView(
            navigationTitle: "Positions",
            itemTypeName: "Position",
            descriptionText: "Manage positions for logging encounters. Built-in positions can be enabled/disabled. Custom positions can be edited or deleted.",
            accentColor: accentColor,
            items: positions,
            onToggle: toggle,
            onDelete: deletePosition,
            addSheet: { PositionFormView(onSave: load) },
            editSheet: { position in
                PositionFormView(position: position, onSave: load)
            },
            itemRow: { position, toggleAction in
                PositionRow(position: position, onToggle: toggleAction)
            }
        )
        .onAppear { load() }
        .alert("Cannot Delete", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "This position cannot be deleted.")
        }
    }

    private func load() {
        positions = (try? service.fetchAllIncludingDisabled()) ?? []
    }

    private func toggle(_ position: SQLPositionType) {
        try? service.toggle(position.id)
        load()
    }

    private func deletePosition(_ position: SQLPositionType) {
        do {
            try service.delete(position.id)
            load()
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }
}

// MARK: - Position Row

private struct PositionRow: View {
    let position: SQLPositionType
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: position.icon,
            name: position.name,
            isEnabled: position.isEnabled,
            isBuiltIn: position.isBuiltIn,
            accentColor: .orange,
            onToggle: onToggle
        )
    }
}
