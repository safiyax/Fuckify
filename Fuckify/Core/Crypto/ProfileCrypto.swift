//
//  ProfileCrypto.swift
//  Fuckify
//

import CryptoKit
import Foundation

struct PlaintextProfile: Codable {
    var displayName: String
    var avatarJpeg:  Data?
}

enum ProfileCryptoError: Error {
    case decryptionFailed
}

enum ProfileCrypto {

    /// Encrypt a profile for upload.
    /// Returns the base64-encoded AES-GCM combined output (nonce + ciphertext + tag).
    /// The nonce is embedded — do NOT send a separate nonce field to the API.
    static func encrypt(_ profile: PlaintextProfile,
                        key: SymmetricKey) throws -> String
    {
        let plaintext = try JSONEncoder().encode(profile)
        let sealed    = try AES.GCM.seal(plaintext, using: key)
        return sealed.combined!.base64EncodedString()
    }

    /// Decrypt a profile blob fetched from the server.
    static func decrypt(blob: String,
                        key: SymmetricKey) throws -> PlaintextProfile
    {
        guard let combined = Data(base64Encoded: blob) else {
            throw ProfileCryptoError.decryptionFailed
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let pt  = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(PlaintextProfile.self, from: pt)
    }
}
