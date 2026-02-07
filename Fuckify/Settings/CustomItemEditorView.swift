//
//  CustomItemEditorView.swift
//  Fuckify
//
//  Views for adding and editing custom activities and protection methods
//

import SwiftUI
import Dependencies

// MARK: - SF Symbol Picker

/// Curated list of relevant SF Symbols for activities and protection methods
private let curatedSymbols = [
    // General
    "heart.fill", "star.fill", "circle.fill", "square.fill", "triangle.fill",
    // Body/People
    "figure.2", "figure.arms.open", "hands.and.sparkles.fill", "hand.raised.fill",
    "mouth", "face.smiling", "face.dashed.fill",
    // Actions
    "bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "moon.stars.fill",
    // Medical/Health
    "pills.fill", "cross.fill", "bandage.fill", "medical.thermometer.fill",
    // Protection
    "shield.fill", "lock.fill", "checkmark.shield.fill", "exclamationmark.shield.fill",
    // Other
    "sparkles", "wand.and.stars", "arrow.uturn.backward", "xmark.circle",
    "ellipsis.circle", "questionmark.circle.fill", "plus.circle.fill"
]

struct SFSymbolPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(curatedSymbols, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: symbol)
                                    .font(.largeTitle)
                                    .foregroundColor(selectedIcon == symbol ? .purple : .primary)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == symbol ? Color.purple.opacity(0.1) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == symbol ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Activity View

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "heart.fill"
    @State private var showingIconPicker = false
    @State private var errorMessage: String?
    
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $name)
                        .autocapitalization(.words)
                }
                
                Section {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .foregroundColor(.purple)
                                .font(.title2)
                        }
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
            .navigationTitle("Add Activity")
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
        
        // Check for duplicates
        let customizationService = CustomizationService()
        let existing = (try? customizationService.fetchAllActivityTypes()) ?? []
        if existing.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "An activity with this name already exists"
            return
        }
        
        do {
            _ = try customizationService.createActivityType(name: trimmedName, icon: selectedIcon)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit Activity View

struct EditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    let activity: SQLActivityTypeEntity
    let onSave: () -> Void
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    
    init(activity: SQLActivityTypeEntity, onSave: @escaping () -> Void) {
        self.activity = activity
        self.onSave = onSave
        _name = State(initialValue: activity.name)
        _selectedIcon = State(initialValue: activity.icon)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Activity Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(activity.isBuiltIn)
                }
                
                Section {
                    Button {
                        if !activity.isBuiltIn {
                            showingIconPicker = true
                        }
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .foregroundColor(.purple)
                                .font(.title2)
                        }
                    }
                    .disabled(activity.isBuiltIn)
                }
                
                if activity.isBuiltIn {
                    Section {
                        Text("Built-in activities cannot be edited or deleted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !activity.isBuiltIn {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Activity", systemImage: "trash")
                        }
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
            .navigationTitle("Edit Activity")
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
                    .disabled(activity.isBuiltIn || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
            .alert("Delete Activity", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteActivity()
                }
            } message: {
                Text("Are you sure you want to delete this activity? This cannot be undone.")
            }
        }
    }
    
    private func saveActivity() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }
        
        var updatedActivity = activity
        updatedActivity.name = trimmedName
        updatedActivity.icon = selectedIcon
        
        do {
            let customizationService = CustomizationService()
            try customizationService.updateActivityType(updatedActivity)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func deleteActivity() {
        do {
            let customizationService = CustomizationService()
            try customizationService.deleteActivityType(id: activity.id)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add Protection Method View

struct AddProtectionMethodView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "shield.fill"
    @State private var showingIconPicker = false
    @State private var errorMessage: String?
    
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Protection Method Name", text: $name)
                        .autocapitalization(.words)
                }
                
                Section {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .foregroundColor(.green)
                                .font(.title2)
                        }
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
            .navigationTitle("Add Protection Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMethod()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
        }
    }
    
    private func saveMethod() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }
        
        // Check for duplicates
        let customizationService = CustomizationService()
        let existing = (try? customizationService.fetchAllProtectionMethods()) ?? []
        if existing.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A protection method with this name already exists"
            return
        }
        
        do {
            _ = try customizationService.createProtectionMethod(name: trimmedName, icon: selectedIcon)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit Protection Method View

struct EditProtectionMethodView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    let method: SQLProtectionMethodEntity
    let onSave: () -> Void
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    
    init(method: SQLProtectionMethodEntity, onSave: @escaping () -> Void) {
        self.method = method
        self.onSave = onSave
        _name = State(initialValue: method.name)
        _selectedIcon = State(initialValue: method.icon)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Protection Method Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(method.isBuiltIn)
                }
                
                Section {
                    Button {
                        if !method.isBuiltIn {
                            showingIconPicker = true
                        }
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    .disabled(method.isBuiltIn)
                }
                
                if method.isBuiltIn {
                    Section {
                        Text("Built-in protection methods cannot be edited or deleted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !method.isBuiltIn {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Protection Method", systemImage: "trash")
                        }
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
            .navigationTitle("Edit Protection Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMethod()
                    }
                    .disabled(method.isBuiltIn || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
            .alert("Delete Protection Method", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteMethod()
                }
            } message: {
                Text("Are you sure you want to delete this protection method? This cannot be undone.")
            }
        }
    }
    
    private func saveMethod() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }
        
        var updatedMethod = method
        updatedMethod.name = trimmedName
        updatedMethod.icon = selectedIcon
        
        do {
            let customizationService = CustomizationService()
            try customizationService.updateProtectionMethod(updatedMethod)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func deleteMethod() {
        do {
            let customizationService = CustomizationService()
            try customizationService.deleteProtectionMethod(id: method.id)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}
