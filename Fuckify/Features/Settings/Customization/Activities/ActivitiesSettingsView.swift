//
//  ActivitiesSettingsView.swift
//  Fuckify
//
//  Settings view for managing activity types
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ActivitiesSettings")

struct ActivitiesSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var activities: [SQLActivityTypeEntity] = []
    @State private var activityToEdit: SQLActivityTypeEntity?
    @State private var activityToDelete: SQLActivityTypeEntity?
    @State private var showingAddActivity = false
    @State private var showingDeleteAlert = false
    
    private let accentColor = Color.purple
    
    var builtInActivities: [SQLActivityTypeEntity] {
        activities.filter { $0.isBuiltIn }
    }
    
    var customActivities: [SQLActivityTypeEntity] {
        activities.filter { !$0.isBuiltIn }
    }

    var body: some View {
        List {
            Section {
                Text("Manage activities for logging encounters. Built-in activities can be enabled/disabled. Custom activities can be edited or deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Built-in Activities
            if !builtInActivities.isEmpty {
                Section("Built-in Activities") {
                    ForEach(builtInActivities) { activity in
                        ActivityRow(
                            activity: activity,
                            onToggle: { toggleActivity(activity) }
                        )
                    }
                }
            }

            // Custom Activities
            Section {
                ForEach(customActivities) { activity in
                    ActivityRow(
                        activity: activity,
                        onToggle: { toggleActivity(activity) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            activityToDelete = activity
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        
                        Button {
                            activityToEdit = activity
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                
                Button {
                    showingAddActivity = true
                } label: {
                    Label("Add Custom Activity", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom Activities")
            } footer: {
                if customActivities.isEmpty {
                    Text("Tap + to add your own custom activities")
                        .font(.caption)
                }
            }
        }
        .tint(.purple)
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddActivity = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .onAppear {
            loadActivities()
        }
        .sheet(isPresented: $showingAddActivity) {
            ActivityFormView(onSave: {
                loadActivities()
            })
            .tint(accentColor)
        }
        .sheet(item: $activityToEdit) { activity in
            ActivityFormView(activity: activity, onSave: {
                loadActivities()
            })
            .tint(accentColor)
        }
        .alert("Delete Activity", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    deleteActivity(activity)
                }
            }
        } message: {
            Text("Are you sure you want to delete this custom activity?")
        }
    }
    
    private func loadActivities() {
        activities = settings.allActivityTypes()
    }
    
    private func toggleActivity(_ activity: SQLActivityTypeEntity) {
        logger.info("Toggling activity: \(activity.id)")
        settings.toggleActivity(activity.id)
        loadActivities()
    }
    
    private func deleteActivity(_ activity: SQLActivityTypeEntity) {
        logger.info("Deleting activity: \(activity.id)")
        settings.deleteActivity(activity.id)
        loadActivities()
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: SQLActivityTypeEntity
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundColor(activity.isEnabled ? .purple : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.body)
                    .foregroundColor(activity.isEnabled ? .primary : .secondary)
                
                if activity.isBuiltIn {
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
            
            Toggle("", isOn: Binding(
                get: { activity.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(activity.name) enabled")
        }
        .padding(.vertical, !activity.isBuiltIn ? 2 : 0)
    }
}
