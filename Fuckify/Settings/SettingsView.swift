//
//  SettingsView.swift
//  Fuckify
//
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    private let config = SettingsConfig.shared

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
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(.pink)
                                    Text("App Icon")
                                }
                            }
                        }

                        if config.showActivities {
                            NavigationLink {
                                ActivitiesSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("Activities")
                                }
                            }
                        }

                        if config.showProtectionMethods {
                            NavigationLink {
                                ProtectionMethodsSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "shield.fill")
                                        .foregroundColor(.green)
                                    Text("Protection Methods")
                                }
                            }
                        }
                        
                        NavigationLink {
                            PartnerAttributesSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.ellipsis")
                                    .foregroundColor(.accentColor)
                                Text("Partner Attributes")
                            }
                        }
                        
                        if config.showSecurity {
                            NavigationLink {
                                SecurityView()
                            } label: {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                    Text("Security")
                                }
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
                                HStack {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(.blue)
                                    Text("Import & Export")
                                        .foregroundColor(.primary)
                                }
                            }
                        }

                        if config.showDeleteData {
                            NavigationLink {
                                DeleteDataView()
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                    Text("Delete Data")
                                }
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
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("About")
                                }
                            }
                        }
                        
                        if config.showSupport {
                            NavigationLink {
                                SupportView()
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.pink)
                                    Text("Support the App")
                                }
                            }
                        }
                        
                        if config.showExperiments {
                            NavigationLink {
                                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
                                    .navigationTitle("Experiments")

                            } label: {
                                HStack {
                                    Image(systemName: "gear.badge.questionmark")
                                        .foregroundColor(.green)
                                    Text("Experiments")
                                }
                            }
                        }
                        
                        // Reset onboarding button
                        Button {
                            hasCompletedOnboarding = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.purple)
                                Text("View Onboarding")
                                    .foregroundColor(.primary)
                            }
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
        }
    }
}

#Preview {
    SettingsView()
}
