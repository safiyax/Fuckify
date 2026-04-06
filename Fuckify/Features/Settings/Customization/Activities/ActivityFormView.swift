//
//  ActivityFormView.swift
//  Fuckify
//
//  Unified form for creating or editing activities
//

import SwiftUI
import Dependencies

struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?
    
    let existingActivity: SQLActivityTypeEntity?
    let onSave: () -> Void
    
    init(activity: SQLActivityTypeEntity? = nil, onSave: @escaping () -> Void) {
        self.existingActivity = activity
        self.onSave = onSave
        
        if let activity = activity {
            _name = State(initialValue: activity.name)
            _selectedIcon = State(initialValue: activity.icon)
        } else {
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: "heart.fill")
        }
    }
    
    var isEditing: Bool {
        existingActivity != nil
    }
    
    var isBuiltIn: Bool {
        existingActivity?.isBuiltIn ?? false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn {
                        Text("Built-in activities cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Icon") {
                    Button {
                        if !isBuiltIn {
                            showingIconPicker = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedIcon)
                                .foregroundColor(.purple)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Choose Icon")
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(isBuiltIn)
                    
                    if isBuiltIn {
                        Text("Built-in activity icons cannot be changed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Activity" : "Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveActivity()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
        }
    }
    
    private func saveActivity() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }
        
        let customizationService = CustomizationService()
        
        do {
            if let existing = existingActivity {
                // Update existing activity
                if isBuiltIn {
                    // Built-in activities cannot be modified
                    dismiss()
                    return
                }
                
                var updated = existing
                updated.name = trimmedName
                updated.icon = selectedIcon
                
                try customizationService.updateActivityType(updated)
            } else {
                // Create new activity - check for duplicates
                let existing = (try? customizationService.fetchAllActivityTypes()) ?? []
                if existing.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                    errorMessage = "An activity with this name already exists"
                    return
                }
                
                _ = try customizationService.createActivityType(name: trimmedName, icon: selectedIcon)
            }
            
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Legacy wrappers for backwards compatibility

typealias AddActivityView = ActivityFormView

struct EditActivityView: View {
    let activity: SQLActivityTypeEntity
    let onSave: () -> Void
    
    var body: some View {
        ActivityFormView(activity: activity, onSave: onSave)
    }
}

#Preview("Add Activity") {
    ActivityFormView {
        print("Saved!")
    }
}

#Preview("Edit Activity") {
    let activity = SQLActivityTypeEntity(
        id: UUID(),
        name: "Kissing",
        icon: "heart.fill",
        isBuiltIn: false,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date()
    )
    
    return ActivityFormView(activity: activity) {
        print("Saved!")
    }
}
