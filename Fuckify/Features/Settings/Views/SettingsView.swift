//
//  SettingsView.swift
//  Fuckify
//
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var showingDebugMenu = false

    var body: some View {
        NavigationStack {
            Form {
//                Section {
//                    Text("Customize which activities and protection methods appear when logging encounters.")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }

                if featureFlags.settings.showPersonalizationSection {
                    Section("Personalization") {
                        if featureFlags.settings.showAppIconPicker {
                            NavigationLink {
                                AppIconSettingsView()
                            } label: {
                                SettingsRow(icon: "app.fill", color: .pink, label: "App Icon")
                            }
                        }

                        if featureFlags.settings.showActivities {
                            NavigationLink {
                                ActivitiesSettingsView()
                            } label: {
                                SettingsRow(icon: "heart.circle.fill", color: .purple, label: "Activities")
                            }
                        }

                        if featureFlags.settings.showProtectionMethods {
                            NavigationLink {
                                ProtectionMethodsSettingsView()
                            } label: {
                                SettingsRow(icon: "shield.fill", color: .green, label: "Protection Methods")
                            }
                        }
                        
                        if featureFlags.settings.showPositions {
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
                        
                        if featureFlags.settings.showSecurity {
                            NavigationLink {
                                SecurityView()
                            } label: {
                                SettingsRow(icon: "lock.fill", color: .orange, label: "Security")
                            }
                        }
                    }
                }

                if featureFlags.settings.showDataSection {
                    Section("Data") {
                        if featureFlags.settings.data.showImportExport {
                            NavigationLink {
                                ImportView()
                            } label: {
                                SettingsRow(icon: "arrow.up.arrow.down", color: .blue, label: "Import & Export")
                            }
                        }

                        if featureFlags.settings.data.showDeleteData {
                            NavigationLink {
                                DeleteDataView()
                            } label: {
                                SettingsRow(icon: "trash.fill", color: .red, label: "Delete Data")
                            }
                        }
                    }
                }

                if featureFlags.settings.showMoreSection {
                    Section("More") {
                        if featureFlags.settings.more.showAbout {
                            NavigationLink {
                                AboutView()
                            } label: {
                                SettingsRow(icon: "info.circle.fill", color: .blue, label: "About")
                            }
                        }
                        
                        if featureFlags.settings.more.showSupportApp {
                            NavigationLink {
                                SupportView()
                            } label: {
                                SettingsRow(icon: "heart.fill", color: .pink, label: "Support the App")
                            }
                        }
                        
                        if featureFlags.settings.more.showExperiments {
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
                if featureFlags.settings.more.showDebugMenu {
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
