//
//  NewDeviceView.swift
//  Fuckify
//

import SwiftUI

struct NewDeviceView: View {
    let username: String
    @Environment(RegistrationCoordinator.self) private var coordinator
    @State private var displayName = ""
    @State private var resolvedUsername = ""

    private var isUsernameKnown: Bool { !username.isEmpty }

    private var canProceed: Bool {
        !displayName.isEmpty &&
        (isUsernameKnown || !resolvedUsername.isEmpty) &&
        !coordinator.isLoading
    }

    var body: some View {
        Form {
            Section {
                Text("Your account was found on the server, but your encryption keys aren't on this device.")
                Text("This happens when you get a new phone — your keys never leave your device and can't be transferred.")
                if isUsernameKnown {
                    Text("Tap below to generate new keys and re-link your account. Your username **@\(username)** is preserved. Your partners will need to re-sync with you after this.")
                } else {
                    Text("Enter your username and display name below to generate new keys and re-link your account. Your partners will need to re-sync with you after this.")
                }
            } header: {
                Text(isUsernameKnown ? "Welcome back, @\(username)" : "Welcome back")
            }

            if !isUsernameKnown {
                Section("Username") {
                    TextField("your_username", text: $resolvedUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }

            Section("Display Name") {
                TextField("Your name", text: $displayName)
            }

            Section {
                Button {
                    let effectiveUsername = isUsernameKnown ? username : resolvedUsername
                    Task { await coordinator.resetIdentity(displayName: displayName, username: effectiveUsername) }
                } label: {
                    if coordinator.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Set Up New Device").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canProceed)
            }
        }
        .navigationTitle("New Device Setup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { coordinator.errorMessage != nil },
            set: { if !$0 { coordinator.errorMessage = nil } }
        )) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        NewDeviceView(username: "alice")
            .environment(RegistrationCoordinator())
    }
}
