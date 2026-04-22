//
//  RegistrationContainerView.swift
//  Fuckify
//

import SwiftUI

struct RegistrationContainerView: View {
    @State private var coordinator = RegistrationCoordinator()

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.step {
                case .phone:
                    PhoneEntryView()
                case .code(let phone):
                    CodeVerifyView(phone: phone)
                case .username:
                    UsernameView()
                case .newDevice(_, let username):
                    NewDeviceView(username: username)
                case .registered(let username):
                    registeredView(username: username)
                }
            }
            .environment(coordinator)
        }
    }

    @ViewBuilder
    private func registeredView(username: String) -> some View {
        ContentUnavailableView(
            "Registered as @\(username)",
            systemImage: "person.crop.circle.fill"
        )
        .navigationTitle("User Registration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RegistrationContainerView()
}
