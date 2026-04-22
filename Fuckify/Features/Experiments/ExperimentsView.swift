//
//  ExperimentsView.swift
//  Fuckify

import SwiftUI

struct ExperimentsView: View {
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var registeredUsername = UserDefaults.standard.string(forKey: "cc.username")

    var body: some View {
        Group {
            if featureFlags.settings.more.experimentsFlags.userRegistration {
                Form {
                    Section {
                        if let username = registeredUsername {
                            LabeledContent("User Registration", value: "Registered as @\(username)")
                        } else {
                            NavigationLink("User Registration") {
                                RegistrationContainerView()
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
            }
        }
        .navigationTitle("Experiments")
        .onAppear {
            registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentsView()
            .environment(FeatureFlagsProvider())
    }
}
