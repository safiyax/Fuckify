//
//  PositionsSettingsView.swift
//  Fuckify
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionsSettings")

struct PositionsSettingsView: View {
    @State private var positions: [SQLPositionType] = []
    @State private var positionToEdit: SQLPositionType?
    @State private var positionToDelete: SQLPositionType?
    @State private var showingAddPosition = false
    @State private var showingDeleteAlert = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    private let service = PositionTypeService()
    private let accentColor = Color.orange

    var builtInPositions: [SQLPositionType] { positions.filter { $0.isBuiltIn } }
    var customPositions: [SQLPositionType] { positions.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            Section {
                Text("Manage positions for logging encounters. Built-in positions can be enabled/disabled. Custom positions can be edited or deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !builtInPositions.isEmpty {
                Section("Built-in Positions") {
                    ForEach(builtInPositions) { position in
                        PositionRow(position: position, onToggle: { toggle(position) })
                    }
                }
            }

            Section {
                ForEach(customPositions) { position in
                    PositionRow(position: position, onToggle: { toggle(position) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                positionToDelete = position
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                positionToEdit = position
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                Button {
                    showingAddPosition = true
                } label: {
                    Label("Add Custom Position", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom Positions")
            } footer: {
                if customPositions.isEmpty {
                    Text("Tap + to add your own custom positions")
                        .font(.caption)
                }
            }
        }
        .tint(accentColor)
        .navigationTitle("Positions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddPosition = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showingAddPosition) {
            PositionFormView(onSave: { load() }).tint(accentColor)
        }
        .sheet(item: $positionToEdit) { position in
            PositionFormView(position: position, onSave: { load() }).tint(accentColor)
        }
        .alert("Delete Position", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let p = positionToDelete { deletePosition(p) }
            }
        } message: {
            Text("Are you sure you want to delete this custom position?")
        }
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

struct PositionRow: View {
    let position: SQLPositionType
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.icon)
                .font(.title3)
                .foregroundColor(position.isEnabled ? .orange : .gray)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(position.name)
                    .foregroundColor(position.isEnabled ? .primary : .secondary)
                if position.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { position.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .accessibilityLabel("\(position.name) enabled")
        }
    }
}
