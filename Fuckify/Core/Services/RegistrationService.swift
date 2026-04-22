//
//  RegistrationService.swift
//  Fuckify
//

import Foundation

final class RegistrationService {
    private let api = APIClient.shared
    private let km  = E2EEKeyManager.shared

    // MARK: - Step 1: Send SMS code

    func sendCode(phone: String) async throws {
        try await api.sendCode(phone: phone)
    }

    // MARK: - Step 2: Verify SMS code

    func verifyCode(phone: String, code: String) async throws -> VerifyResp {
        let resp = try await api.verifyCode(phone: phone, code: code)
        return resp
    }

    // MARK: - Step 3a: Complete registration (new user)

    func completeRegistration(username: String, displayName: String) async throws {
        let bundle = try km.installAndBuildRegistrationBundle(opkCount: 100)
        let profileKey = try ProfileKeyManager.shared.profileKey()
        let blob = try ProfileCrypto.encrypt(
            PlaintextProfile(displayName: displayName, avatarJpeg: nil),
            key: profileKey
        )
        let opks = bundle.oneTimePrekeys.map {
            ["prekey_id": String($0.id), "public_key": $0.publicKey]
        }
        try await api.completeRegistration(
            username:            username,
            encryptedBlob:       blob,
            identitySigningPub:  bundle.identitySigningPub,
            identityAgreementPub: bundle.identityAgreementPub,
            signedPrekeyId:      bundle.signedPrekeyId,
            signedPrekeyPub:     bundle.signedPrekeyPub,
            signedPrekeySig:     bundle.signedPrekeySig,
            oneTimePrekeys:      opks
        )
        UserDefaults.standard.set(username, forKey: "cc.username")
    }

    // MARK: - Step 3b: Reset identity (returning user on new device)

    func resetIdentity(displayName: String) async throws {
        // Generate completely fresh keys — overwrites any existing Keychain entries
        let bundle = try km.installAndBuildRegistrationBundle(opkCount: 100)
        let profileKey = try ProfileKeyManager.shared.profileKey()
        let blob = try ProfileCrypto.encrypt(
            PlaintextProfile(displayName: displayName, avatarJpeg: nil),
            key: profileKey
        )
        let opks = bundle.oneTimePrekeys.map {
            ["prekey_id": String($0.id), "public_key": $0.publicKey]
        }
        try await api.resetIdentity(
            encryptedBlob:        blob,
            identitySigningPub:   bundle.identitySigningPub,
            identityAgreementPub: bundle.identityAgreementPub,
            signedPrekeyId:       bundle.signedPrekeyId,
            signedPrekeyPub:      bundle.signedPrekeyPub,
            signedPrekeySig:      bundle.signedPrekeySig,
            oneTimePrekeys:       opks
        )
        // Username is preserved on server — no UserDefaults write needed
    }
}
