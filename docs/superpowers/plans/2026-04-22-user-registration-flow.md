# User Registration Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully end-to-end phone-number → SMS code → username registration flow with real CryptoKit key generation, AES-GCM profile encryption, and new-device re-registration support, surfaced under Settings > Experiments > User Registration.

**Architecture:** A `RegistrationCoordinator` (`@Observable @MainActor`) owns a `RegistrationStep` enum and drives a `NavigationStack`. `RegistrationService` (plain `final class`) calls `APIClient` for network, and invokes `E2EEKeyManager` / `ProfileKeyManager` / `ProfileCrypto` from `Core/Crypto/` for all cryptographic operations. All crypto types are pure Foundation + CryptoKit with no SwiftUI dependencies.

**Tech Stack:** Swift, SwiftUI, CryptoKit (Curve25519, AES-GCM, HKDF, HMAC), URLSession, Keychain (Security framework), `@Observable` (iOS 17+)

---

## File Map

### Created
| File | Purpose |
|------|---------|
| `Fuckify/Core/Crypto/KeychainStore.swift` | Low-level Keychain read/write/delete |
| `Fuckify/Core/Crypto/E2EEKeyManager.swift` | Identity key generation + Keychain storage |
| `Fuckify/Core/Crypto/ProfileKeyManager.swift` | Profile key storage |
| `Fuckify/Core/Crypto/ProfileCrypto.swift` | AES-GCM profile encrypt/decrypt |
| `Fuckify/Core/Services/APIClient.swift` | URLSession HTTP client, registration endpoints |
| `Fuckify/Core/Services/RegistrationService.swift` | Orchestrates send-code → verify-code → complete/reset |
| `Fuckify/Features/Experiments/ExperimentsView.swift` | Experiments settings screen |
| `Fuckify/Features/Registration/RegistrationCoordinator.swift` | `@Observable` state machine |
| `Fuckify/Features/Registration/RegistrationContainerView.swift` | NavigationStack driven by coordinator step |
| `Fuckify/Features/Registration/PhoneEntryView.swift` | Phone number entry screen |
| `Fuckify/Features/Registration/CodeVerifyView.swift` | SMS code verification screen |
| `Fuckify/Features/Registration/UsernameView.swift` | Username + display name screen (new users) |
| `Fuckify/Features/Registration/NewDeviceView.swift` | New-device re-registration screen |

### Modified
| File | Change |
|------|--------|
| `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift` | Add `ExperimentsFlags` struct + `experimentsFlags` on `SettingsMoreFlags` |
| `Fuckify/Features/Settings/Debug/DebugMenuView.swift` | Add `settings.more.experiments` sub-section |
| `Fuckify/Features/Settings/Views/SettingsView.swift` | Replace inline `ContentUnavailableView` with `ExperimentsView()` |
| `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift` | Update base URL to dev endpoint |

---

## Task 1: Update Feature Flags URL to Dev

**Files:**
- Modify: `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift:13`

- [ ] **Step 1: Update the base URL**

In `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift`, change line 13 from:
```swift
    private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"
```
To:
```swift
    private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"
```

- [ ] **Step 2: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**
```bash
git add Fuckify/Features/FeatureFlags/FeatureFlagsService.swift
git commit -m "fix: point feature flags service at dev API"
```

---

## Task 2: Wire Feature Flag — `ExperimentsFlags` and Debug Menu Row

**Files:**
- Modify: `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift`
- Modify: `Fuckify/Features/Settings/Debug/DebugMenuView.swift`

- [ ] **Step 1: Add `ExperimentsFlags` struct and wire it into `SettingsMoreFlags`**

In `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift`, after the closing `}` of `SettingsMoreFlags` (currently line 215), append:

```swift

// MARK: - ExperimentsFlags

@MainActor
struct ExperimentsFlags {
    let provider: FeatureFlagsProvider
    var userRegistration: Bool { provider.isEnabled(.settingsMoreExperimentsUserRegistration) }
}
```

Then add `experimentsFlags` to `SettingsMoreFlags`. Find:
```swift
    var debugMenu: Bool   { provider.isEnabled(.settingsMoreDebugMenu) }
}
```
Replace with:
```swift
    var debugMenu: Bool   { provider.isEnabled(.settingsMoreDebugMenu) }
    var experimentsFlags: ExperimentsFlags { ExperimentsFlags(provider: provider) }
}
```

- [ ] **Step 2: Add `settings.more.experiments` sub-section to `DebugMenuView`**

In `Fuckify/Features/Settings/Debug/DebugMenuView.swift`, find:
```swift
                // MARK: App Info
                Section("App Info") {
```
Insert before it:
```swift
                // MARK: settings.more.experiments
                Section("settings.more.experiments") {
                    flagRow("  userRegistration",
                            key: "settings.more.experiments.userRegistration",
                            current: featureFlags.settings.more.experimentsFlags.userRegistration)
                }

```

- [ ] **Step 3: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**
```bash
git add Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift Fuckify/Features/Settings/Debug/DebugMenuView.swift
git commit -m "feat: add ExperimentsFlags and userRegistration debug row"
```

---

## Task 3: Core Crypto — `KeychainStore`

**Files:**
- Create: `Fuckify/Core/Crypto/KeychainStore.swift`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p Fuckify/Core/Crypto
```

Create `Fuckify/Core/Crypto/KeychainStore.swift`:

```swift
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
```

- [ ] **Step 2: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**
```bash
git add Fuckify/Core/Crypto/KeychainStore.swift
git commit -m "feat: add KeychainStore helper"
```

---

## Task 4: Core Crypto — `E2EEKeyManager`, `ProfileKeyManager`, `ProfileCrypto`

**Files:**
- Create: `Fuckify/Core/Crypto/E2EEKeyManager.swift`
- Create: `Fuckify/Core/Crypto/ProfileKeyManager.swift`
- Create: `Fuckify/Core/Crypto/ProfileCrypto.swift`

- [ ] **Step 1: Create `E2EEKeyManager.swift`**

Create `Fuckify/Core/Crypto/E2EEKeyManager.swift`:

```swift
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
```

Note: `hasIdentityKeys()` is added beyond the frontend.md spec — it is used by the coordinator to detect the new-device case.

- [ ] **Step 2: Create `ProfileKeyManager.swift`**

Create `Fuckify/Core/Crypto/ProfileKeyManager.swift`:

```swift
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
```

- [ ] **Step 3: Create `ProfileCrypto.swift`**

Create `Fuckify/Core/Crypto/ProfileCrypto.swift`:

```swift
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
```

Note: `ProfileCrypto.encrypt` in `frontend.md` returns `(blob: String, nonce: String)` but the API spec's `POST /api/auth/complete` has no separate `nonce` field. This implementation returns only the combined blob string to match the API.

- [ ] **Step 4: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 5: Commit**
```bash
git add Fuckify/Core/Crypto/E2EEKeyManager.swift Fuckify/Core/Crypto/ProfileKeyManager.swift Fuckify/Core/Crypto/ProfileCrypto.swift
git commit -m "feat: add E2EEKeyManager, ProfileKeyManager, ProfileCrypto"
```

---

## Task 5: Core Services — `APIClient`

**Files:**
- Create: `Fuckify/Core/Services/APIClient.swift`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p Fuckify/Core/Services
```

Create `Fuckify/Core/Services/APIClient.swift`:

```swift
//
//  APIClient.swift
//  Fuckify
//

import Foundation

// MARK: - Error types

enum APIError: Error, LocalizedError {
    case server(status: Int, message: String)
    case network(URLError)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .server(_, let msg): return msg
        case .network(let e):     return e.localizedDescription
        case .decoding:           return "Unexpected server response."
        }
    }
}

private struct PocketBaseError: Decodable {
    let status: Int
    let message: String
}

// MARK: - Response types

struct VerifyResp: Decodable {
    let token: String
    let userID: String
    let isNewUser: Bool
    enum CodingKeys: String, CodingKey {
        case token
        case userID    = "user_id"
        case isNewUser = "is_new_user"
    }
}

private struct SentResp: Decodable { let sent: Bool }
private struct AvailableResp: Decodable { let available: Bool }
struct OKResp: Decodable { let ok: Bool }

// MARK: - Client

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "https://dev.coitalcomra.de")!
    var authToken: String?

    // MARK: - Registration

    func sendCode(phone: String) async throws {
        struct Body: Encodable { let phone: String }
        let _: SentResp = try await post("/api/auth/send-code", body: Body(phone: phone))
    }

    func verifyCode(phone: String, code: String) async throws -> VerifyResp {
        struct Body: Encodable { let phone: String; let code: String }
        return try await post("/api/auth/verify-code", body: Body(phone: phone, code: code))
    }

    func checkUsername(_ username: String) async throws -> Bool {
        let r: AvailableResp = try await get("/api/auth/check-username?username=\(username)")
        return r.available
    }

    func completeRegistration(
        username: String,
        encryptedBlob: String,
        identitySigningPub: String,
        identityAgreementPub: String,
        signedPrekeyId: UInt32,
        signedPrekeyPub: String,
        signedPrekeySig: String,
        oneTimePrekeys: [[String: String]]
    ) async throws {
        struct Body: Encodable {
            let username: String
            let encrypted_blob: String
            let identity_signing_pub: String
            let identity_agreement_pub: String
            let signed_prekey_id: UInt32
            let signed_prekey_pub: String
            let signed_prekey_sig: String
            let one_time_prekeys: [[String: String]]
        }
        let _: OKResp = try await post("/api/auth/complete", body: Body(
            username:               username,
            encrypted_blob:         encryptedBlob,
            identity_signing_pub:   identitySigningPub,
            identity_agreement_pub: identityAgreementPub,
            signed_prekey_id:       signedPrekeyId,
            signed_prekey_pub:      signedPrekeyPub,
            signed_prekey_sig:      signedPrekeySig,
            one_time_prekeys:       oneTimePrekeys
        ))
    }

    func resetIdentity(
        encryptedBlob: String,
        identitySigningPub: String,
        identityAgreementPub: String,
        signedPrekeyId: UInt32,
        signedPrekeyPub: String,
        signedPrekeySig: String,
        oneTimePrekeys: [[String: String]]
    ) async throws {
        struct Body: Encodable {
            let encrypted_blob: String
            let identity_signing_pub: String
            let identity_agreement_pub: String
            let signed_prekey_id: UInt32
            let signed_prekey_pub: String
            let signed_prekey_sig: String
            let one_time_prekeys: [[String: String]]
        }
        let _: OKResp = try await post("/api/auth/reset-identity", body: Body(
            encrypted_blob:         encryptedBlob,
            identity_signing_pub:   identitySigningPub,
            identity_agreement_pub: identityAgreementPub,
            signed_prekey_id:       signedPrekeyId,
            signed_prekey_pub:      signedPrekeyPub,
            signed_prekey_sig:      signedPrekeySig,
            one_time_prekeys:       oneTimePrekeys
        ))
    }

    // MARK: - Generic helpers

    func post<T: Decodable>(_ path: String, body: Encodable) async throws -> T {
        try await req("POST", path, body: body)
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await req("GET", path)
    }

    private func req<T: Decodable>(_ method: String, _ path: String,
                                    body: Encodable? = nil) async throws -> T
    {
        var r = URLRequest(url: baseURL.appendingPathComponent(path))
        r.httpMethod = method
        r.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = authToken {
            r.addValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            r.httpBody = try JSONEncoder().encode(b)
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: r)
        } catch let e as URLError {
            throw APIError.network(e)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        guard (200..<300).contains(http.statusCode) else {
            if let pb = try? JSONDecoder().decode(PocketBaseError.self, from: data) {
                throw APIError.server(status: pb.status, message: pb.message)
            }
            throw APIError.server(status: http.statusCode, message: "Request failed.")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
```

- [ ] **Step 2: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**
```bash
git add Fuckify/Core/Services/APIClient.swift
git commit -m "feat: add APIClient with registration endpoints"
```

---

## Task 6: Core Services — `RegistrationService`

**Files:**
- Create: `Fuckify/Core/Services/RegistrationService.swift`

- [ ] **Step 1: Create the file**

Create `Fuckify/Core/Services/RegistrationService.swift`:

```swift
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
```

- [ ] **Step 2: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**
```bash
git add Fuckify/Core/Services/RegistrationService.swift
git commit -m "feat: add RegistrationService"
```

---

## Task 7: Registration Coordinator

**Files:**
- Create: `Fuckify/Features/Registration/RegistrationCoordinator.swift`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p Fuckify/Features/Registration
```

Create `Fuckify/Features/Registration/RegistrationCoordinator.swift`:

```swift
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
                if E2EEKeyManager.shared.hasIdentityKeys() {
                    // Keys present — already set up on this device
                    let username = UserDefaults.standard.string(forKey: "cc.username") ?? ""
                    if username.isEmpty {
                        errorMessage = "Account found but username not stored on this device."
                    } else {
                        step = .registered(username: username)
                    }
                } else {
                    // New device — no local keys
                    let username = UserDefaults.standard.string(forKey: "cc.username") ?? ""
                    if username.isEmpty {
                        errorMessage = "Account found but username not stored on this device. Re-registration on a fresh device without prior app data is not supported in this experiment."
                    } else {
                        step = .newDevice(token: resp.token, username: username)
                    }
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
```

- [ ] **Step 2: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**
```bash
git add Fuckify/Features/Registration/RegistrationCoordinator.swift
git commit -m "feat: add RegistrationCoordinator state machine"
```

---

## Task 8: Registration UI Views

**Files:**
- Create: `Fuckify/Features/Registration/RegistrationContainerView.swift`
- Create: `Fuckify/Features/Registration/PhoneEntryView.swift`
- Create: `Fuckify/Features/Registration/CodeVerifyView.swift`
- Create: `Fuckify/Features/Registration/UsernameView.swift`
- Create: `Fuckify/Features/Registration/NewDeviceView.swift`

- [ ] **Step 1: Create `RegistrationContainerView.swift`**

Create `Fuckify/Features/Registration/RegistrationContainerView.swift`:

```swift
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
```

- [ ] **Step 2: Create `PhoneEntryView.swift`**

Create `Fuckify/Features/Registration/PhoneEntryView.swift`:

```swift
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
        var digits = input.filter { $0.isNumber }
        if input.hasPrefix("+") {
            return "+" + digits
        }
        // If user typed digits without +, prepend +
        return digits.isEmpty ? "" : "+" + digits
    }
}

#Preview {
    NavigationStack {
        PhoneEntryView()
            .environment(RegistrationCoordinator())
    }
}
```

- [ ] **Step 3: Create `CodeVerifyView.swift`**

Create `Fuckify/Features/Registration/CodeVerifyView.swift`:

```swift
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
                        // Limit to 6 digits
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
```

- [ ] **Step 4: Create `UsernameView.swift`**

Create `Fuckify/Features/Registration/UsernameView.swift`:

```swift
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
```

- [ ] **Step 5: Create `NewDeviceView.swift`**

Create `Fuckify/Features/Registration/NewDeviceView.swift`:

```swift
//
//  NewDeviceView.swift
//  Fuckify
//

import SwiftUI

struct NewDeviceView: View {
    let username: String
    @Environment(RegistrationCoordinator.self) private var coordinator
    @State private var displayName = ""

    var body: some View {
        Form {
            Section {
                Text("Your account was found on the server, but your encryption keys aren't on this device.")
                Text("This happens when you get a new phone — your keys never leave your device and can't be transferred.")
                Text("Tap below to generate new keys and re-link your account. Your username **@\(username)** is preserved. Your partners will need to re-sync with you after this.")
            } header: {
                Text("Welcome back, @\(username)")
            }

            Section("Display Name") {
                TextField("Your name", text: $displayName)
            }

            Section {
                Button {
                    Task { await coordinator.resetIdentity(displayName: displayName, username: username) }
                } label: {
                    if coordinator.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Set Up New Device").frame(maxWidth: .infinity)
                    }
                }
                .disabled(displayName.isEmpty || coordinator.isLoading)
            }
        }
        .navigationTitle("New Device Setup")
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
        NewDeviceView(username: "alice")
            .environment(RegistrationCoordinator())
    }
}
```

- [ ] **Step 6: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 7: Commit**
```bash
git add Fuckify/Features/Registration/
git commit -m "feat: add registration UI views"
```

---

## Task 9: Experiments View and Settings Wiring

**Files:**
- Create: `Fuckify/Features/Experiments/ExperimentsView.swift`
- Modify: `Fuckify/Features/Settings/Views/SettingsView.swift:113-116`

- [ ] **Step 1: Create the directory and `ExperimentsView.swift`**

```bash
mkdir -p Fuckify/Features/Experiments
```

Create `Fuckify/Features/Experiments/ExperimentsView.swift`:

```swift
//
//  ExperimentsView.swift
//  Fuckify
//

import SwiftUI

struct ExperimentsView: View {
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var registeredUsername = UserDefaults.standard.string(forKey: "cc.username")

    var body: some View {
        Group {
            if featureFlags.settings.more.experimentsFlags.userRegistration {
                Form {
                    Section {
                        if let username = registeredUsername {
                            LabeledContent("User Registration", value: "Registered as @\(username)")
                        } else {
                            NavigationLink("User Registration") {
                                RegistrationContainerView()
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
            }
        }
        .navigationTitle("Experiments")
        .onAppear {
            registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentsView()
            .environment(FeatureFlagsProvider())
    }
}
```

- [ ] **Step 2: Replace the inline `ContentUnavailableView` in `SettingsView`**

In `Fuckify/Features/Settings/Views/SettingsView.swift`, find:
```swift
                        if featureFlags.settings.more.experiments {
                            NavigationLink {
                                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
                                    .navigationTitle("Experiments")

                            } label: {
                                SettingsRow(icon: "gear.badge.questionmark", color: .green, label: "Experiments")
                            }
                        }
```

Replace with:
```swift
                        if featureFlags.settings.more.experiments {
                            NavigationLink {
                                ExperimentsView()
                            } label: {
                                SettingsRow(icon: "gear.badge.questionmark", color: .green, label: "Experiments")
                            }
                        }
```

- [ ] **Step 3: Build**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 4: Commit**
```bash
git add Fuckify/Features/Experiments/ExperimentsView.swift Fuckify/Features/Settings/Views/SettingsView.swift
git commit -m "feat: add ExperimentsView and wire into Settings"
```

---

## Task 10: Smoke Test

- [ ] **Step 1: Verify no PostHog or old references remain**
```bash
grep -r "PostHog\|SettingsConfig\|ImportExportConfig" Fuckify/ --include="*.swift"
```
Expected: zero results

- [ ] **Step 2: Build for simulator**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Manual verification checklist**

Run the app on the simulator and verify:

1. **Feature flag gating** — with `settings.more.experiments.userRegistration` OFF (default), navigating to Settings > Experiments shows "Nothing to see here." With it ON (toggle in debug menu), the "User Registration" row appears.

2. **Phone entry** — enter a valid E.164 phone number, tap Send Code. Spinner appears, then code screen pushes.

3. **Code verification** — enter the 6-digit SMS code. Spinner appears. If `is_new_user: true`, username screen pushes.

4. **Username screen** — type a username; after 500ms, availability check fires. Green checkmark when available. Enter a display name. Tap Finish. On success, "Registered as @username" screen appears.

5. **Already-registered** — kill and relaunch the app. Navigate to Settings > Experiments. Row shows "Registered as @username" (LabeledContent, not tappable).

6. **Debug menu flag row** — open debug menu, confirm `settings.more.experiments` section appears with `userRegistration` toggle and orange dot behavior works.

- [ ] **Step 4: Commit any fixes**
```bash
git add -A
git commit -m "fix: smoke test fixes"
```
