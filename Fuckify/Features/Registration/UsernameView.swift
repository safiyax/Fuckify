//
//  UsernameView.swift
//  Fuckify
//

import SwiftUI

struct UsernameView: View {
    @Environment(RegistrationCoordinator.self) private var coordinator
    @State private var username = ""
    @State private var displayName = ""
    @State private var usernameAvailable: Bool? = nil
    @State private var checkTask: Task<Void, Never>? = nil
    @State private var isCheckingUsername = false

    private var canFinish: Bool {
        usernameAvailable == true && !displayName.isEmpty && !coordinator.isLoading
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) { _, _ in scheduleUsernameCheck() }

                    if isCheckingUsername {
                        ProgressView()
                    } else if let available = usernameAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? .green : .red)
                    }
                }
            } header: {
                Text("Username")
            } footer: {
                Text("3–32 characters. Letters, numbers, _ and - only.")
            }

            Section("Display Name") {
                TextField("Your name", text: $displayName)
            }

            Section {
                Button {
                    Task { await coordinator.completeRegistration(username: username, displayName: displayName) }
                } label: {
                    if coordinator.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Finish").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canFinish)
            }
        }
        .navigationTitle("Choose Username")
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

    private func scheduleUsernameCheck() {
        usernameAvailable = nil
        checkTask?.cancel()
        guard !username.isEmpty else { return }
        checkTask = Task {
            isCheckingUsername = true
            defer { isCheckingUsername = false }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            usernameAvailable = try? await APIClient.shared.checkUsername(username)
        }
    }
}

#Preview {
    NavigationStack {
        UsernameView()
            .environment(RegistrationCoordinator())
    }
}
