//
//  ExperimentsView.swift
//  Fuckify

import SwiftUI

struct ExperimentsView: View {
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @Environment(PremiumManager.self) private var premium
    @State private var registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
    @State private var showManagement = false

    var body: some View {
        Group {
            if featureFlags.settings.more.experimentsFlags.userRegistration ||
               featureFlags.settings.more.experimentsFlags.paywall ||
               featureFlags.settings.more.experimentsFlags.sheetRedesign ||
               featureFlags.settings.more.experimentsFlags.animatedBackground {
                Form {
                    if featureFlags.settings.more.experimentsFlags.userRegistration {
                        Section {
                            if let username = registeredUsername {
                                LabeledContent("User Registration", value: "Registered as @\(username)")
                            } else {
                                NavigationLink("User Registration") {
                                    RegistrationContainerView()
                                }
                            }
                        } header: {
                            Text("Online Features")
                        }
                    }

                    if featureFlags.settings.more.experimentsFlags.sheetRedesign ||
                       featureFlags.settings.more.experimentsFlags.animatedBackground {
                        Section("Redesign") {
                            if featureFlags.settings.more.experimentsFlags.sheetRedesign {
                                NavigationLink("Bottom Sheet") {
                                    BottomSheetView()
                                }
                            }
                            if featureFlags.settings.more.experimentsFlags.animatedBackground {
                                NavigationLink("Animated Background") {
                                    AnimatedBlobBackground()
                                }
                            }
                        }
                    }

                    if featureFlags.settings.more.experimentsFlags.paywall {
                        Section {
                            NavigationLink("Paywall Sheet") {
                                PaywallView()
                            }
                            LabeledContent("Premium", value: premium.isPremium ? "Active" : "Not Active")
                                .contentShape(Rectangle())
                                .onTapGesture { showManagement = true }
                        } header: {
                            Text("Paywall Features")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
            }
        }
        .navigationTitle("Experiments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
        }
        .task {
            await premium.load()
        }
        .sheet(isPresented: $showManagement) {
            PremiumManagementView()
                .environment(premium)
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentsView()
            .environment(FeatureFlagsProvider())
            .environment(PremiumManager.shared)
    }
}
