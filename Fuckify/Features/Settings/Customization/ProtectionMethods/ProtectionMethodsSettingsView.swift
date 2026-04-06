//
//  ProtectionMethodsSettingsView.swift
//  Fuckify
//
//  Settings view for managing protection methods
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ProtectionMethodsSettings")

struct ProtectionMethodsSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var protectionMethods: [SQLProtectionMethodEntity] = []
    @State private var methodToEdit: SQLProtectionMethodEntity?
    @State private var methodToDelete: SQLProtectionMethodEntity?
    @State private var showingAddMethod = false
    @State private var showingDeleteAlert = false
    
    private let accentColor = Color.green
    
    var builtInMethods: [SQLProtectionMethodEntity] {
        protectionMethods.filter { $0.isBuiltIn }
    }
    
    var customMethods: [SQLProtectionMethodEntity] {
        protectionMethods.filter { !$0.isBuiltIn }
    }

    var body: some View {
        List {
            Section {
                Text("Manage protection methods for logging encounters. Built-in methods can be enabled/disabled. Custom methods can be edited or deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Built-in Protection Methods
            if !builtInMethods.isEmpty {
                Section("Built-in Methods") {
                    ForEach(builtInMethods) { method in
                        ProtectionMethodRow(
                            method: method,
                            onToggle: { toggleMethod(method) }
                        )
                    }
                }
            }

            // Custom Protection Methods
            Section {
                ForEach(customMethods) { method in
                    ProtectionMethodRow(
                        method: method,
                        onToggle: { toggleMethod(method) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            methodToDelete = method
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        
                        Button {
                            methodToEdit = method
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                
                Button {
                    showingAddMethod = true
                } label: {
                    Label("Add Custom Protection Method", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom Methods")
            } footer: {
                if customMethods.isEmpty {
                    Text("Tap + to add your own custom protection methods")
                        .font(.caption)
                }
            }
        }
        .tint(accentColor)
        .navigationTitle("Protection Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMethod = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .onAppear {
            loadProtectionMethods()
        }
        .sheet(isPresented: $showingAddMethod) {
            ProtectionMethodFormView(onSave: {
                loadProtectionMethods()
            })
            .tint(accentColor)
        }
        .sheet(item: $methodToEdit) { method in
            ProtectionMethodFormView(method: method, onSave: {
                loadProtectionMethods()
            })
            .tint(accentColor)
        }
        .alert("Delete Protection Method", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let method = methodToDelete {
                    deleteMethod(method)
                }
            }
        } message: {
            Text("Are you sure you want to delete this custom protection method?")
        }
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

struct ProtectionMethodRow: View {
    let method: SQLProtectionMethodEntity
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: method.icon)
                .font(.title3)
                .foregroundColor(method.isEnabled ? .green : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(method.name)
                    .font(.body)
                    .foregroundColor(method.isEnabled ? .primary : .secondary)
                
                if method.isBuiltIn {
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
                get: { method.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(method.name) enabled")
        }
        .padding(.vertical, !method.isBuiltIn ? 2 : 0)
    }
}
