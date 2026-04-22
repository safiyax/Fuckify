//
//  ProfileKeyManager.swift
//  Fuckify
//

import CryptoKit
import Foundation

final class ProfileKeyManager {
    static let shared = ProfileKeyManager()
    private let store = KeychainStore(service: "com.myapp.profile")
    private let account = "profileKey"

    func profileKey() throws -> SymmetricKey {
        if let raw = try? store.get(account: account) {
            return SymmetricKey(data: raw)
        }
        let key = SymmetricKey(size: .bits256)
        try store.set(key.withUnsafeBytes { Data($0) }, account: account)
        return key
    }

    func profileKeyRawBytes() throws -> Data {
        try profileKey().withUnsafeBytes { Data($0) }
    }

    func cachePartnerKey(_ key: SymmetricKey, forUsername username: String) throws {
        try store.set(key.withUnsafeBytes { Data($0) },
                      account: "partnerProfileKey.\(username)")
    }

    func partnerKey(forUsername username: String) throws -> SymmetricKey {
        SymmetricKey(data: try store.get(account: "partnerProfileKey.\(username)"))
    }
}
