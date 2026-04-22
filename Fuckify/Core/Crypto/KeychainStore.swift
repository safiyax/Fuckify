//
//  KeychainStore.swift
//  Fuckify
//

import Foundation
import Security

enum KeychainError: Error {
    case status(OSStatus)
    case notFound
    case badData
}

struct KeychainStore {
    let service: String

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String:       kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func set(_ data: Data, account: String) throws {
        var q = query(account)
        q[kSecValueData as String]      = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let s = SecItemAdd(q as CFDictionary, nil)
        if s == errSecDuplicateItem {
            let u = SecItemUpdate(query(account) as CFDictionary,
                                  [kSecValueData as String: data] as CFDictionary)
            guard u == errSecSuccess else { throw KeychainError.status(u) }
        } else if s != errSecSuccess {
            throw KeychainError.status(s)
        }
    }

    func get(account: String) throws -> Data {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let s = SecItemCopyMatching(q as CFDictionary, &item)
        guard s == errSecSuccess else {
            throw s == errSecItemNotFound ? KeychainError.notFound : KeychainError.status(s)
        }
        guard let d = item as? Data else { throw KeychainError.badData }
        return d
    }

    func delete(account: String) throws {
        let s = SecItemDelete(query(account) as CFDictionary)
        guard s == errSecSuccess || s == errSecItemNotFound else {
            throw KeychainError.status(s)
        }
    }
}
