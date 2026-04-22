//
//  E2EEKeyManager.swift
//  Fuckify
//

import CryptoKit
import Foundation

protocol Initialisable {
    init<D: ContiguousBytes>(rawRepresentation: D) throws
    var rawRepresentation: Data { get }
}
extension Curve25519.Signing.PrivateKey:      Initialisable {}
extension Curve25519.KeyAgreement.PrivateKey: Initialisable {}

final class E2EEKeyManager {
    static let shared = E2EEKeyManager()
    private let store = KeychainStore(service: "com.myapp.e2ee.identity")

    private enum K {
        static let identitySign  = "identity.sign.priv"
        static let identityAgree = "identity.agree.priv"
        static func spk(_ id: UInt32) -> String { "spk.\(id).priv" }
        static func opk(_ id: UInt32) -> String { "opk.\(id).priv" }
    }

    // MARK: - Registration bundle

    struct RegistrationBundle {
        let identitySigningPub:   String   // base64
        let identityAgreementPub: String   // base64
        let signedPrekeyId:       UInt32
        let signedPrekeyPub:      String   // base64
        let signedPrekeySig:      String   // base64
        let oneTimePrekeys:       [(id: UInt32, publicKey: String)]
    }

    /// Generates all identity keys and OPKs, stores private keys in Keychain,
    /// returns public halves ready for upload. Call once at first launch.
    func installAndBuildRegistrationBundle(opkCount: Int = 100) throws -> RegistrationBundle {
        let signKey  = try loadOrCreate(Curve25519.Signing.PrivateKey.self,
                                        account: K.identitySign) {
            Curve25519.Signing.PrivateKey()
        }
        let agreeKey = try loadOrCreate(Curve25519.KeyAgreement.PrivateKey.self,
                                        account: K.identityAgree) {
            Curve25519.KeyAgreement.PrivateKey()
        }

        let spkID = UInt32.random(in: 1...UInt32.max)
        let spk   = Curve25519.KeyAgreement.PrivateKey()
        try store.set(spk.rawRepresentation, account: K.spk(spkID))
        let spkSig = try signKey.signature(for: spk.publicKey.rawRepresentation)

        var opks: [(id: UInt32, publicKey: String)] = []
        for _ in 0..<opkCount {
            let id  = UInt32.random(in: 1...UInt32.max)
            let key = Curve25519.KeyAgreement.PrivateKey()
            try store.set(key.rawRepresentation, account: K.opk(id))
            opks.append((id: id, publicKey: key.publicKey.rawRepresentation.base64EncodedString()))
        }

        return RegistrationBundle(
            identitySigningPub:   signKey.publicKey.rawRepresentation.base64EncodedString(),
            identityAgreementPub: agreeKey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekeyId:       spkID,
            signedPrekeyPub:      spk.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekeySig:      Data(spkSig).base64EncodedString(),
            oneTimePrekeys:       opks
        )
    }

    // MARK: - Key accessors

    func identitySigningKey() throws -> Curve25519.Signing.PrivateKey {
        try .init(rawRepresentation: store.get(account: K.identitySign))
    }
    func identityAgreementKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        try .init(rawRepresentation: store.get(account: K.identityAgree))
    }

    /// Returns true if identity signing key exists in Keychain (device has been set up).
    func hasIdentityKeys() -> Bool {
        (try? store.get(account: K.identitySign)) != nil
    }

    func signedPrekey(id: UInt32) throws -> Curve25519.KeyAgreement.PrivateKey {
        try .init(rawRepresentation: store.get(account: K.spk(id)))
    }
    func oneTimePrekey(id: UInt32) throws -> Curve25519.KeyAgreement.PrivateKey {
        try .init(rawRepresentation: store.get(account: K.opk(id)))
    }
    func deleteOneTimePrekey(id: UInt32) {
        try? store.delete(account: K.opk(id))
    }

    // MARK: - Private

    private func loadOrCreate<K: Initialisable>(
        _ type: K.Type, account: String, make: () -> K
    ) throws -> K {
        if let d = try? store.get(account: account) { return try K(rawRepresentation: d) }
        let k = make()
        try store.set(k.rawRepresentation, account: account)
        return k
    }
}
