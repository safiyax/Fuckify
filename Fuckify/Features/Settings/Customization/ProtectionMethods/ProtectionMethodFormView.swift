//
//  ProtectionMethodFormView.swift
//  Fuckify
//
//  Unified form for creating or editing protection methods
//

import SwiftUI
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ProtectionMethodForm")

struct ProtectionMethodFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?
    
    let existingMethod: SQLProtectionMethodEntity?
    let onSave: () -> Void
    
    init(method: SQLProtectionMethodEntity? = nil, onSave: @escaping () -> Void) {
        self.existingMethod = method
        self.onSave = onSave
        
        if let method = method {
            _name = State(initialValue: method.name)
            _selectedIcon = State(initialValue: method.icon)
        } else {
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: "shield.fill")
        }
    }
    
    var isEditing: Bool {
        existingMethod != nil
    }
    
    var isBuiltIn: Bool {
        existingMethod?.isBuiltIn ?? false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Protection Method Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn {
                        Text("Built-in protection methods cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Icon") {
                    IconPickerRow(
                        selectedIcon: $selectedIcon,
                        accentColor: .green,
                        isDisabled: isBuiltIn,
                        onTap: { showingIconPicker = true }
                    )
                    
                    if isBuiltIn {
                        Text("Built-in protection method icons cannot be changed")
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
            .navigationTitle(isEditing ? "Edit Protection Method" : "Add Protection Method")
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
        
        let customizationService = CustomizationService()
        
        do {
            if let existing = existingMethod {
                // Update existing method
                if isBuiltIn {
                    // Built-in methods cannot be modified
                    dismiss()
                    return
                }
                
                var updated = existing
                updated.name = trimmedName
                updated.icon = selectedIcon
                
                try customizationService.updateProtectionMethod(updated)
            } else {
                // Create new method - check for duplicates
                let existing = (try? customizationService.fetchAllProtectionMethods()) ?? []
                if existing.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                    errorMessage = "A protection method with this name already exists"
                    return
                }
                
                _ = try customizationService.createProtectionMethod(name: trimmedName, icon: selectedIcon)
            }
            
            logger.info("\(isEditing ? "Updated" : "Created") protection method")
            onSave()
            dismiss()
        } catch {
            logger.error("Failed to save protection method: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Legacy wrappers for backwards compatibility

typealias AddProtectionMethodView = ProtectionMethodFormView

struct EditProtectionMethodView: View {
    let method: SQLProtectionMethodEntity
    let onSave: () -> Void
    
    var body: some View {
        ProtectionMethodFormView(method: method, onSave: onSave)
    }
}

#Preview("Add Protection Method") {
    ProtectionMethodFormView {
        print("Saved!")
    }
}

#Preview("Edit Protection Method") {
    let method = SQLProtectionMethodEntity(
        id: UUID(),
        name: "Condom",
        icon: "shield.fill",
        isBuiltIn: false,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date()
    )
    
    return ProtectionMethodFormView(method: method) {
        print("Saved!")
    }
}
