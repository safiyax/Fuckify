//
//  ProtectionMethodsSettingsView.swift
//  Fuckify
//
//  Settings view for managing protection methods
//

import SwiftUI

// MARK: - Protection Methods Settings View

/// Sheet presentation mode for protection method form
enum ProtectionMethodFormMode: Identifiable {
    case add
    case edit(method: SQLProtectionMethodEntity)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let method): return "edit-\(method.id)"
        }
    }
}

struct ProtectionMethodsSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var protectionMethods: [SQLProtectionMethodEntity] = []
    @State private var methodFormMode: ProtectionMethodFormMode?

    var body: some View {
        Form {
            Section {
                Text("Toggle which protection methods appear when logging encounters. Tap to edit custom methods.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(protectionMethods) { method in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { method.isEnabled },
                            set: { _ in
                                settings.toggleProtectionMethod(method.id)
                                loadProtectionMethods()
                            }
                        )) {
                            HStack {
                                Image(systemName: method.icon)
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text(method.name)
                                
                                if method.isBuiltIn {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Only allow editing custom methods
                        if !method.isBuiltIn {
                            Button {
                                methodFormMode = .edit(method: method)
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button {
                    methodFormMode = .add
                } label: {
                    Label("Add Custom Protection Method", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Protection Methods")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProtectionMethods()
        }
        .sheet(item: $methodFormMode) { mode in
            switch mode {
            case .add:
                AddProtectionMethodView(onSave: {
                    loadProtectionMethods()
                })
            case .edit(let method):
                EditProtectionMethodView(method: method, onSave: {
                    loadProtectionMethods()
                })
            }
        }
    }
    
    private func loadProtectionMethods() {
        protectionMethods = settings.allProtectionMethods()
    }
}
