//
//  CodeVerifyView.swift
//  Fuckify
//

import SwiftUI

struct CodeVerifyView: View {
    let phone: String
    @Environment(RegistrationCoordinator.self) private var coordinator
    @State private var code = ""

    var body: some View {
        Form {
            Section {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .onChange(of: code) { _, new in
                        code = String(new.filter { $0.isNumber }.prefix(6))
                    }
            } header: {
                Text("Verification Code")
            } footer: {
                Text("Enter the 6-digit code sent to \(phone).")
            }

            Section {
                Button {
                    Task { await coordinator.verifyCode(phone: phone, code: code) }
                } label: {
                    if coordinator.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Verify").frame(maxWidth: .infinity)
                    }
                }
                .disabled(code.count != 6 || coordinator.isLoading)

                Button("Resend Code") {
                    Task { await coordinator.sendCode(phone: phone) }
                }
                .disabled(coordinator.isLoading)
            }
        }
        .navigationTitle("Enter Code")
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
        CodeVerifyView(phone: "+14155552671")
            .environment(RegistrationCoordinator())
    }
}
