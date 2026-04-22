//
//  PhoneEntryView.swift
//  Fuckify
//

import SwiftUI

struct PhoneEntryView: View {
    @Environment(RegistrationCoordinator.self) private var coordinator
    @State private var phone = ""

    var body: some View {
        Form {
            Section {
                TextField("+1 555 000 0000", text: $phone)
                    .keyboardType(.phonePad)
                    .onChange(of: phone) { _, new in
                        phone = formatE164(new)
                    }
            } header: {
                Text("Phone Number")
            } footer: {
                Text("We'll send you a one-time code to verify your number. Your number is never stored on our servers.")
            }

            Section {
                Button {
                    Task { await coordinator.sendCode(phone: phone) }
                } label: {
                    if coordinator.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(phone.count < 8 || coordinator.isLoading)
            }
        }
        .navigationTitle("User Registration")
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

    /// Ensures input stays in E.164 format: leading +, then digits only.
    private func formatE164(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        if input.hasPrefix("+") {
            return "+" + digits
        }
        return digits.isEmpty ? "" : "+" + digits
    }
}

#Preview {
    NavigationStack {
        PhoneEntryView()
            .environment(RegistrationCoordinator())
    }
}
