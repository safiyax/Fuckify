//
//  RegistrationCoordinator.swift
//  Fuckify
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "Registration")

// MARK: - Step enum

enum RegistrationStep: Equatable {
    case phone
    case code(phone: String)
    case username(phone: String, token: String, userID: String)  // new user
    case newDevice(token: String, username: String)              // returning user, no local keys
    case registered(username: String)
}

// MARK: - Coordinator

@Observable
@MainActor
final class RegistrationCoordinator {
    private(set) var step: RegistrationStep
    private(set) var isLoading = false
    var errorMessage: String? = nil

    private let service = RegistrationService()
    private let tokenStore = KeychainStore(service: "baby.safi.Fuckify.auth")

    init() {
        if let username = UserDefaults.standard.string(forKey: "cc.username") {
            step = .registered(username: username)
        } else {
            step = .phone
        }
    }

    // MARK: - Actions

    func sendCode(phone: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.sendCode(phone: phone)
            step = .code(phone: phone)
        } catch {
            logger.error("sendCode failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func verifyCode(phone: String, code: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await service.verifyCode(phone: phone, code: code)

            // Store token
            try? tokenStore.set(Data(resp.token.utf8), account: "bearerToken")
            APIClient.shared.authToken = resp.token

            if resp.isNewUser {
                step = .username(phone: phone, token: resp.token, userID: resp.userID)
            } else {
                // Returning user — check if keys are on this device
                let cachedUsername = UserDefaults.standard.string(forKey: "cc.username") ?? ""
                if E2EEKeyManager.shared.hasIdentityKeys() && !cachedUsername.isEmpty {
                    // Keys + username present — fully set up on this device
                    step = .registered(username: cachedUsername)
                } else {
                    // No keys or no cached username — treat as new device setup.
                    // clearIdentityKeys() is called inside RegistrationService.resetIdentity
                    // so any partial state is cleaned up at the point of commitment.
                    step = .newDevice(token: resp.token, username: cachedUsername)
                }
            }
        } catch {
            logger.error("verifyCode failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func completeRegistration(username: String, displayName: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.completeRegistration(username: username, displayName: displayName)
            step = .registered(username: username)
        } catch {
            logger.error("completeRegistration failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func resetIdentity(displayName: String, username: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.resetIdentity(displayName: displayName)
            step = .registered(username: username)
        } catch {
            logger.error("resetIdentity failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
