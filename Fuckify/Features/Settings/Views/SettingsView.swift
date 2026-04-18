//
//  SettingsView.swift
//  Fuckify
//
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @State private var config = SettingsConfig.shared
    @State private var showingDebugMenu = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Customize which activities and protection methods appear when logging encounters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if config.showPersonalizationSection {
                    Section("Personalization") {
                        if config.showAppIconPicker {
                            NavigationLink {
                                AppIconSettingsView()
                            } label: {
                                SettingsRow(icon: "app.fill", color: .pink, label: "App Icon")
                            }
                        }

                        if config.showActivities {
                            NavigationLink {
                                ActivitiesSettingsView()
                            } label: {
                                SettingsRow(icon: "heart.circle.fill", color: .purple, label: "Activities")
                            }
                        }

                        if config.showProtectionMethods {
                            NavigationLink {
                                ProtectionMethodsSettingsView()
                            } label: {
                                SettingsRow(icon: "shield.fill", color: .green, label: "Protection Methods")
                            }
                        }
                        
                        if config.showPositions {
                            NavigationLink {
                                PositionsSettingsView()
                            } label: {
                                SettingsRow(icon: "arrow.up.arrow.down.circle.fill", color: .orange, label: "Positions")
                            }
                        }
                        
                        NavigationLink {
                            PartnerAttributesSettingsView()
                        } label: {
                            SettingsRow(icon: "person.crop.circle.badge.ellipsis", color: .accentColor, label: "Partner Attributes")
                        }
                        
                        if config.showSecurity {
                            NavigationLink {
                                SecurityView()
                            } label: {
                                SettingsRow(icon: "lock.fill", color: .orange, label: "Security")
                            }
                        }
                    }
                }

                if config.showDataSection {
                    Section("Data") {
                        if config.showImportExport {
                            NavigationLink {
                                ImportView()
                            } label: {
                                SettingsRow(icon: "arrow.up.arrow.down", color: .blue, label: "Import & Export")
                            }
                        }

                        if config.showDeleteData {
                            NavigationLink {
                                DeleteDataView()
                            } label: {
                                SettingsRow(icon: "trash.fill", color: .red, label: "Delete Data")
                            }
                        }
                    }
                }

                if config.showMoreSection {
                    Section("More") {
                        if config.showAbout {
                            NavigationLink {
                                AboutView()
                            } label: {
                                SettingsRow(icon: "info.circle.fill", color: .blue, label: "About")
                            }
                        }
                        
                        if config.showSupport {
                            NavigationLink {
                                SupportView()
                            } label: {
                                SettingsRow(icon: "heart.fill", color: .pink, label: "Support the App")
                            }
                        }
                        
                        if config.showExperiments {
                            NavigationLink {
                                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
                                    .navigationTitle("Experiments")

                            } label: {
                                SettingsRow(icon: "gear.badge.questionmark", color: .green, label: "Experiments")
                            }
                        }
                        
                        // Reset onboarding button
                        Button {
                            hasCompletedOnboarding = false
                        } label: {
                            SettingsRow(icon: "arrow.clockwise.circle.fill", color: .purple, label: "View Onboarding")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Debug Menu (only visible when CCDebugMenu flag is enabled)
                if config.showDebugMenu {
                    Section("Developer") {
                        Button {
                            showingDebugMenu = true
                        } label: {
                            SettingsRow(icon: "ladybug.fill", color: .red, label: "Debug Menu")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Close", systemImage: "xmark")
                    }
                    
                }
            }
            .dismissOnAppLock()
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
            }
        }
    }
}

#Preview {
    SettingsView()
}
