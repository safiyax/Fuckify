# Frontend — Swift / iOS
### Complete Implementation Reference

---

## What we are building

This is the complete iOS client for an intimate encounter tracking app where two partners can securely sync their shared encounter history. Every piece of sensitive data — encounters, partner details, display names, avatars — is encrypted on-device before it ever touches the network. The server is a dumb relay that cannot read any of it.

### Cryptographic stack
The app implements the **Signal Protocol** from scratch using Apple's **CryptoKit** exclusively. No third-party crypto libraries are used, which means `ITSAppUsesNonExemptEncryption = NO` in `Info.plist` — Apple's own frameworks have already handled export compliance for these primitives.

The cryptographic layers, bottom to top:

**X3DH (Extended Triple Diffie-Hellman)** — used once per partner pair to establish a shared secret (`SK`) without either party ever transmitting it. Alice fetches Bob's public key bundle (identity key, signed prekey, one-time prekey), performs four Diffie-Hellman operations against her own keys and an ephemeral key, and runs the result through HKDF-SHA256 to produce `SK`. Bob can reproduce the same `SK` from his private keys and Alice's public ephemeral. The server sees only public keys and never `SK`.

**Double Ratchet** — layered on top of X3DH. Every sync operation advances the ratchet, producing a fresh single-use message key via HMAC-SHA256 chain ratcheting. The DH ratchet (using `Curve25519.KeyAgreement`) injects new entropy on each sync direction change, providing:
- **Forward secrecy** — compromise of the current state cannot decrypt past syncs
- **Post-compromise security** — after one full sync round-trip post-compromise, the attacker is locked out

**AES-256-GCM** — used for all symmetric encryption (sync payloads, profile data, persisted ratchet state). Each encryption uses a fresh random nonce. The associated data binds ciphertexts to both parties' identity keys, preventing cross-session replay.

**Safety numbers** — a 60-digit fingerprint derived from both users' Ed25519 identity keys using Signal's iterated SHA-512 algorithm (5200 rounds). Users compare this code in person to confirm they are talking to each other and not a man-in-the-middle.

### Registration flow
1. User enters phone number → Twilio SMS code sent
2. User enters code → server verifies with Twilio → auth token issued
3. New users: choose username and set display name/avatar
4. App generates all identity keys on-device, stores private keys in Keychain (`WhenUnlockedThisDeviceOnly`, no iCloud backup)
5. Display name and avatar are encrypted with a randomly generated **profile key** before upload — the server receives only ciphertext
6. Public key bundle and encrypted profile uploaded atomically in one request

### Partner and sync flow
1. Alice sends a partner request to Bob by username
2. Bob accepts → relationship is `active`
3. Alice and Bob meet in person, open the Safety Number screen, compare their 60-digit codes, and tap "Mark as Verified"
4. Alice taps "Sync with Bob":
   - App builds a `SyncBatch` containing all encounters involving Bob, all relevant junction table rows, any third-party partner records, and only the custom (non-built-in) catalog types referenced
   - On first sync, Alice's **profile key** is included in the batch so Bob can decrypt her profile from the server
   - The batch is encrypted with the Double Ratchet and posted to the server as an opaque blob (phase 1)
   - Bob's app decrypts it, merges with his local data, encrypts his own batch, and posts it back (phase 2)
   - Alice decrypts phase 2 and performs the final merge
5. **Conflict resolution:** two encounters are the same event if they share duration (±60s), activities, protection methods, and participant positions. The initiator's version wins on conflicts. Unique encounters on either side are always kept.

### Key storage architecture
- **Identity private keys** — Keychain, `WhenUnlockedThisDeviceOnly`
- **Profile key** — Keychain, `WhenUnlockedThisDeviceOnly`
- **Partner profile keys** — Keychain, per-partner entry
- **Double Ratchet session state** — AES-GCM encrypted file on disk (iOS Data Protection: `CompleteFileProtectionUntilFirstUserAuthentication`), with the session encryption key (SEK) stored in Keychain
- **TOFU identity pins** — Keychain, one entry per partner username

### File structure
```
Crypto/          — all cryptographic primitives, no UI dependencies
Models/          — Codable wire models for the sync batch
Services/        — network and business logic
Views/           — SwiftUI views only, no crypto logic
```

---

All Swift code for the app. `ITSAppUsesNonExemptEncryption = NO` — every
cryptographic primitive uses Apple's CryptoKit (Curve25519, AES-GCM, HKDF,
HMAC, SHA-512). No third-party crypto libraries.

---

## Project structure

```
MyApp/
├── Crypto/
│   ├── KeychainStore.swift          # low-level Keychain helper
│   ├── E2EEKeyManager.swift         # identity key generation + storage
│   ├── ProfileKeyManager.swift      # profile key storage + partner key cache
│   ├── ProfileCrypto.swift          # profile AES-GCM encrypt/decrypt
│   ├── SafetyNumber.swift           # 60-digit fingerprint (Signal algorithm)
│   ├── IdentityPinStore.swift       # TOFU pin storage + E2EEError
│   ├── X3DH.swift                   # X3DH key agreement
│   ├── DoubleRatchet.swift          # DR state + encrypt/decrypt algorithm
│   └── DoubleRatchetSession.swift   # session wrapper + disk persistence
├── Models/
│   ├── Encounter.swift              # local SQLite model (your existing SQL structs)
│   └── SyncModels.swift             # Codable wire models for sync batch
├── Services/
│   ├── APIClient.swift              # HTTP to PocketBase
│   ├── RegistrationService.swift    # phone verify + complete registration
│   └── SyncService.swift           # encounter sync orchestration
└── Views/
    ├── Registration/
    │   ├── RegistrationView.swift   # top-level registration flow coordinator
    │   ├── PhoneEntryView.swift
    │   ├── CodeVerifyView.swift
    │   └── ProfileSetupView.swift
    └── Main/
        ├── PartnersListView.swift
        ├── AddPartnerView.swift
        ├── SafetyNumberView.swift
        └── SyncView.swift
```

---

## `Crypto/KeychainStore.swift`

```swift
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

---

## `Crypto/E2EEKeyManager.swift`

```swift
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

---

## `Crypto/ProfileKeyManager.swift`

```swift
import CryptoKit
import Foundation

/// Manages the 32-byte profile key.
/// - Lives only on device in Keychain (WhenUnlockedThisDeviceOnly).
/// - Shared with partners inside the encrypted DR sync channel.
/// - Never sent to the server in plaintext.
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

    /// Cache a partner's profile key received via the DR sync channel.
    func cachePartnerKey(_ key: SymmetricKey, forUsername username: String) throws {
        try store.set(key.withUnsafeBytes { Data($0) },
                      account: "partnerProfileKey.\(username)")
    }

    func partnerKey(forUsername username: String) throws -> SymmetricKey {
        SymmetricKey(data: try store.get(account: "partnerProfileKey.\(username)"))
    }
}
```

---

## `Crypto/ProfileCrypto.swift`

```swift
import CryptoKit
import Foundation

struct PlaintextProfile: Codable {
    var displayName: String
    var avatarJpeg:  Data?
}

enum ProfileCrypto {

    /// Encrypt a profile for upload. Returns (base64 combined ciphertext, base64 nonce).
    static func encrypt(_ profile: PlaintextProfile,
                        key: SymmetricKey) throws -> (blob: String, nonce: String)
    {
        let plaintext = try JSONEncoder().encode(profile)
        let nonce     = AES.GCM.Nonce()
        let sealed    = try AES.GCM.seal(plaintext, using: key, nonce: nonce,
                                         authenticating: Data())
        return (sealed.combined!.base64EncodedString(),
                Data(nonce).base64EncodedString())
    }

    /// Decrypt a profile blob fetched from the server.
    static func decrypt(blob: String,
                        key: SymmetricKey) throws -> PlaintextProfile
    {
        guard let combined = Data(base64Encoded: blob) else {
            throw E2EEError.decryptionFailed
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let pt  = try AES.GCM.open(box, using: key, authenticating: Data())
        return try JSONDecoder().decode(PlaintextProfile.self, from: pt)
    }
}
```

---

## `Crypto/SafetyNumber.swift`

```swift
import CryptoKit
import Foundation

/// Generates a Signal-compatible 60-digit safety number.
/// Algorithm: iterated SHA-512 (5200 rounds) over each party's identity key,
/// truncated to 30 digits per party, combined in sorted order.
enum SafetyNumber {

    static func combined(localIK: Data, localUsername: String,
                         remoteIK: Data, remoteUsername: String) -> String
    {
        let a = thirtyDigits(fingerprint(ik: localIK,  id: localUsername))
        let b = thirtyDigits(fingerprint(ik: remoteIK, id: remoteUsername))
        return a <= b ? a + b : b + a
    }

    /// Format the 60-digit string as space-separated groups of 5 for display.
    static func formatted(_ digits: String) -> String {
        stride(from: 0, to: 60, by: 5).map { i -> String in
            let s = digits.index(digits.startIndex, offsetBy: i)
            let e = digits.index(s, offsetBy: 5)
            return String(digits[s..<e])
        }.joined(separator: " ")
    }

    private static func fingerprint(ik: Data, id: String) -> Data {
        var input = Data([0x00, 0x00]) + ik + Data(id.utf8) + ik
        var digest = Data(SHA512.hash(data: input))
        for _ in 1..<5200 {
            digest = Data(SHA512.hash(data: digest + ik))
        }
        return digest
    }

    private static func thirtyDigits(_ fp: Data) -> String {
        stride(from: 0, to: 30, by: 5).map { i -> String in
            var n: UInt64 = 0
            for b in fp[i..<i+5] { n = (n << 8) | UInt64(b) }
            return String(format: "%05d", n % 100_000)
        }.joined()
    }
}
```

---

## `Crypto/IdentityPinStore.swift`

```swift
import Foundation

enum E2EEError: Error, LocalizedError {
    case safetyNumberChanged(String)
    case noSession
    case decryptionFailed
    case noActivePartner

    var errorDescription: String? {
        switch self {
        case .safetyNumberChanged(let u):
            return "Safety number changed for \(u). Verify in person again."
        case .noSession:       return "No encryption session found. Sync again."
        case .decryptionFailed: return "Could not decrypt data."
        case .noActivePartner:  return "No active partner relationship found."
        }
    }
}

/// TOFU (Trust On First Use) identity pin store.
/// On first contact with a peer, pins their identity keys.
/// On subsequent contacts, raises an error if the keys changed —
/// which could indicate a MITM attack or device reinstall.
final class IdentityPinStore {
    static let shared = IdentityPinStore()
    private let store = KeychainStore(service: "com.myapp.e2ee.pins")

    func checkOrPin(username: String, signingPub: Data, agreementPub: Data) throws {
        let expected = signingPub + agreementPub
        do {
            let existing = try store.get(account: "pin.\(username)")
            guard existing == expected else {
                throw E2EEError.safetyNumberChanged(username)
            }
        } catch KeychainError.notFound {
            try store.set(expected, account: "pin.\(username)")
        }
    }

    func markVerified(_ username: String) throws {
        try store.set(Data([1]), account: "verified.\(username)")
    }

    func isVerified(_ username: String) -> Bool {
        (try? store.get(account: "verified.\(username)")) == Data([1])
    }

    func clearPin(_ username: String) throws {
        try store.delete(account: "pin.\(username)")
        try store.delete(account: "verified.\(username)")
    }
}
```

---

## `Crypto/X3DH.swift`

```swift
import CryptoKit
import Foundation

struct KeyBundle: Decodable {
    let username:             String
    let identitySigningPub:   Data
    let identityAgreementPub: Data
    let signedPrekeyID:       UInt32
    let signedPrekeyPub:      Data
    let signedPrekeySig:      Data
    let oneTimePrekey:        OTPKBundle?

    struct OTPKBundle: Decodable { let prekeyID: UInt32; let publicKey: Data }

    enum CodingKeys: String, CodingKey {
        case username
        case identitySigningPub   = "identity_signing_pub"
        case identityAgreementPub = "identity_agreement_pub"
        case signedPrekeyID       = "signed_prekey_id"
        case signedPrekeyPub      = "signed_prekey_pub"
        case signedPrekeySig      = "signed_prekey_sig"
        case oneTimePrekey        = "one_time_prekey"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        username             = try c.decode(String.self, forKey: .username)
        identitySigningPub   = try Data(base64Encoded: c.decode(String.self, forKey: .identitySigningPub))!
        identityAgreementPub = try Data(base64Encoded: c.decode(String.self, forKey: .identityAgreementPub))!
        signedPrekeyID       = try c.decode(UInt32.self, forKey: .signedPrekeyID)
        signedPrekeyPub      = try Data(base64Encoded: c.decode(String.self, forKey: .signedPrekeyPub))!
        signedPrekeySig      = try Data(base64Encoded: c.decode(String.self, forKey: .signedPrekeySig))!
        oneTimePrekey        = try c.decodeIfPresent(OTPKBundle.self, forKey: .oneTimePrekey)
    }
}

enum X3DH {
    private static let hkdfInfo = Data("MyApp/X3DH/v1".utf8)
    private static let hkdfSalt = Data(repeating: 0, count: 32)

    struct Result {
        let sharedSecret:       SymmetricKey
        let ephemeralPublicKey: Data
        let usedSPKID:          UInt32
        let usedOPKID:          UInt32?
    }

    /// Alice: fetch bundle → verify SPK sig → run 3 or 4 DHs → HKDF → SK.
    static func initiate(myAgreementKey: Curve25519.KeyAgreement.PrivateKey,
                         bundle: KeyBundle) throws -> Result
    {
        let peerSignPub = try Curve25519.Signing.PublicKey(
            rawRepresentation: bundle.identitySigningPub)
        guard peerSignPub.isValidSignature(bundle.signedPrekeySig,
                                           for: bundle.signedPrekeyPub) else {
            throw CryptoKitError.authenticationFailure
        }
        let peerIK  = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: bundle.identityAgreementPub)
        let peerSPK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: bundle.signedPrekeyPub)
        let ek      = Curve25519.KeyAgreement.PrivateKey()

        var ikm = Data(repeating: 0xFF, count: 32) // X3DH domain-separation prefix
        func appendDH(_ priv: Curve25519.KeyAgreement.PrivateKey,
                      _ pub: Curve25519.KeyAgreement.PublicKey) throws {
            let s = try priv.sharedSecretFromKeyAgreement(with: pub)
            s.withUnsafeBytes { ikm.append(contentsOf: $0) }
        }
        try appendDH(myAgreementKey, peerSPK) // DH1
        try appendDH(ek, peerIK)              // DH2
        try appendDH(ek, peerSPK)             // DH3

        var opkID: UInt32?
        if let opk = bundle.oneTimePrekey {
            let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: opk.publicKey)
            try appendDH(ek, pub)              // DH4
            opkID = opk.prekeyID
        }

        let sk = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: hkdfSalt, info: hkdfInfo, outputByteCount: 32)

        return Result(sharedSecret: sk,
                      ephemeralPublicKey: ek.publicKey.rawRepresentation,
                      usedSPKID: bundle.signedPrekeyID,
                      usedOPKID: opkID)
    }

    /// Bob: mirror Alice's DHs using private keys → same SK.
    static func respond(myIdentityKey: Curve25519.KeyAgreement.PrivateKey,
                        mySignedPrekey: Curve25519.KeyAgreement.PrivateKey,
                        myOneTimePrekey: Curve25519.KeyAgreement.PrivateKey?,
                        theirIdentityPub: Data,
                        theirEphemeralPub: Data) throws -> SymmetricKey
    {
        let theirIK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirIdentityPub)
        let theirEK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirEphemeralPub)

        var ikm = Data(repeating: 0xFF, count: 32)
        func appendDH(_ priv: Curve25519.KeyAgreement.PrivateKey,
                      _ pub: Curve25519.KeyAgreement.PublicKey) throws {
            let s = try priv.sharedSecretFromKeyAgreement(with: pub)
            s.withUnsafeBytes { ikm.append(contentsOf: $0) }
        }
        try appendDH(mySignedPrekey, theirIK)  // DH1
        try appendDH(myIdentityKey,  theirEK)  // DH2
        try appendDH(mySignedPrekey, theirEK)  // DH3
        if let opk = myOneTimePrekey {
            try appendDH(opk, theirEK)         // DH4
        }

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: hkdfSalt, info: hkdfInfo, outputByteCount: 32)
    }
}
```

---

## `Crypto/DoubleRatchet.swift`

```swift
import CryptoKit
import Foundation

// MARK: - KDF primitives

enum RatchetKDF {
    static let rkInfo = Data("MyApp/DoubleRatchet/RootKey/v1".utf8)

    /// KDF_RK: HKDF-SHA256(salt=RK, IKM=DH output) → (newRK 32B, chainKey 32B)
    static func kdfRK(rk: SymmetricKey,
                      dhOut: SharedSecret) -> (rk: SymmetricKey, ck: SymmetricKey)
    {
        let ikm  = SymmetricKey(data: dhOut.withUnsafeBytes { Data($0) })
        let salt = rk.withUnsafeBytes { Data($0) }
        let out  = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt,
                                          info: rkInfo, outputByteCount: 64)
        let b = out.withUnsafeBytes { Data($0) }
        return (SymmetricKey(data: b.prefix(32)), SymmetricKey(data: b.suffix(32)))
    }

    /// KDF_CK: HMAC-SHA256(CK, 0x01) → MK;  HMAC-SHA256(CK, 0x02) → nextCK
    static func kdfCK(ck: SymmetricKey) -> (mk: SymmetricKey, nextCK: SymmetricKey) {
        (SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data([0x01]), using: ck))),
         SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data([0x02]), using: ck))))
    }
}

// MARK: - Codable key wrapper

struct WireKey: Codable, Hashable, Equatable, Sendable {
    var raw: Data
    init(_ k: SymmetricKey)                       { raw = k.withUnsafeBytes { Data($0) } }
    init(_ k: Curve25519.KeyAgreement.PrivateKey) { raw = k.rawRepresentation }
    init(_ k: Curve25519.KeyAgreement.PublicKey)  { raw = k.rawRepresentation }
    var sym: SymmetricKey { SymmetricKey(data: raw) }
    func priv() throws -> Curve25519.KeyAgreement.PrivateKey { try .init(rawRepresentation: raw) }
    func pub()  throws -> Curve25519.KeyAgreement.PublicKey  { try .init(rawRepresentation: raw) }
}

// MARK: - Ratchet state

struct DoubleRatchetState: Codable, Sendable {
    var DHs: WireKey; var DHr: WireKey?
    var RK: WireKey;  var CKs: WireKey?; var CKr: WireKey?
    var Ns: UInt32 = 0; var Nr: UInt32 = 0; var PN: UInt32 = 0
    var MKSKIPPED: [SkippedKey: WireKey] = [:]
    var maxSkip:  UInt32 = 1000
    var maxCache: Int    = 2000
}

struct SkippedKey: Codable, Hashable, Sendable { let dhr: Data; let n: UInt32 }

// MARK: - Wire types

struct RatchetHeader: Codable, Equatable, Sendable {
    let dh: Data; let pn: UInt32; let n: UInt32
    func canonicalBytes() -> Data {
        var d = dh
        var p = pn.bigEndian; withUnsafeBytes(of: &p) { d.append(contentsOf: $0) }
        var m = n.bigEndian;  withUnsafeBytes(of: &m) { d.append(contentsOf: $0) }
        return d
    }
}

struct EncryptedPayload: Codable, Equatable, Sendable {
    let header: RatchetHeader
    let ciphertext: Data  // AES-GCM combined: nonce(12) + ct + tag(16)
}

struct WireSyncEnvelope: Codable, Sendable {
    enum MessageType: String, Codable {
        case x3dhInitial = "x3dh_initial"
        case ratchet
    }
    let type:                       MessageType
    let senderIdentityAgreementPub: Data
    let senderIdentitySigningPub:   Data
    let ratchet:                    EncryptedPayload
    let ephemeralPub:               Data?
    let usedSignedPrekeyID:         UInt32?
    let usedOneTimePrekeyID:        UInt32?
}

// MARK: - AEAD helpers

enum RatchetAEAD {
    static func buildAD(sessionAD: Data, header: RatchetHeader) -> Data {
        var d = Data()
        var l = UInt32(sessionAD.count).bigEndian
        withUnsafeBytes(of: &l) { d.append(contentsOf: $0) }
        d.append(sessionAD); d.append(header.canonicalBytes())
        return d
    }
    static func encrypt(mk: SymmetricKey, pt: Data, ad: Data) throws -> Data {
        try AES.GCM.seal(pt, using: mk, nonce: AES.GCM.Nonce(),
                         authenticating: ad).combined!
    }
    static func decrypt(mk: SymmetricKey, ct: Data, ad: Data) throws -> Data {
        try AES.GCM.open(try AES.GCM.SealedBox(combined: ct),
                         using: mk, authenticating: ad)
    }
}

// MARK: - Double Ratchet algorithm

enum DoubleRatchet {

    // MARK: Initialisation

    /// Alice (initiator): performs first DH ratchet step against Bob's SPK.
    /// Produces a live sending chain immediately.
    static func initAlice(sk: SymmetricKey,
                          bobSPKPub: Curve25519.KeyAgreement.PublicKey) throws -> DoubleRatchetState
    {
        let dhs = Curve25519.KeyAgreement.PrivateKey()
        let dhOut = try dhs.sharedSecretFromKeyAgreement(with: bobSPKPub)
        let (rk, cks) = RatchetKDF.kdfRK(rk: sk, dhOut: dhOut)
        return DoubleRatchetState(
            DHs: WireKey(dhs), DHr: WireKey(bobSPKPub),
            RK: WireKey(rk), CKs: WireKey(cks))
    }

    /// Bob (responder): stashes SK as RK, uses SPK private as initial DHs.
    /// No sending chain until first decrypt triggers dhRatchetStep.
    static func initBob(sk: SymmetricKey,
                        bobSPKPriv: Curve25519.KeyAgreement.PrivateKey) -> DoubleRatchetState
    {
        DoubleRatchetState(DHs: WireKey(bobSPKPriv), RK: WireKey(sk))
    }

    // MARK: Encrypt

    static func encrypt(state: inout DoubleRatchetState,
                        plaintext: Data,
                        sessionAD: Data) throws -> EncryptedPayload
    {
        guard let cks = state.CKs else { throw E2EEError.noSession }
        let (mk, nextCK) = RatchetKDF.kdfCK(ck: cks.sym)
        let hdr = RatchetHeader(dh: state.DHs.raw, pn: state.PN, n: state.Ns)
        let ad  = RatchetAEAD.buildAD(sessionAD: sessionAD, header: hdr)
        let ct  = try RatchetAEAD.encrypt(mk: mk, pt: plaintext, ad: ad)
        state.CKs = WireKey(nextCK)
        state.Ns += 1
        // mk goes out of scope here → forward secrecy
        return EncryptedPayload(header: hdr, ciphertext: ct)
    }

    // MARK: Decrypt

    static func decrypt(state: inout DoubleRatchetState,
                        payload: EncryptedPayload,
                        sessionAD: Data) throws -> Data
    {
        var w = state
        let ad = RatchetAEAD.buildAD(sessionAD: sessionAD, header: payload.header)

        // Case 1: skipped message key
        let sk = SkippedKey(dhr: payload.header.dh, n: payload.header.n)
        if let mk = w.MKSKIPPED.removeValue(forKey: sk) {
            let pt = try RatchetAEAD.decrypt(mk: mk.sym, ct: payload.ciphertext, ad: ad)
            state = w; return pt
        }

        // Case 2: DH ratchet step
        if w.DHr?.raw != payload.header.dh {
            try skipMessageKeys(&w, until: payload.header.pn)
            try dhRatchetStep(&w, header: payload.header)
        }

        // Case 3: advance receiving chain
        try skipMessageKeys(&w, until: payload.header.n)
        guard let ckr = w.CKr else { throw E2EEError.noSession }
        let (mk, nextCK) = RatchetKDF.kdfCK(ck: ckr.sym)
        w.CKr = WireKey(nextCK); w.Nr += 1

        let pt = try RatchetAEAD.decrypt(mk: mk, ct: payload.ciphertext, ad: ad)
        state = w
        return pt
    }

    // MARK: - Private helpers

    private static func skipMessageKeys(_ s: inout DoubleRatchetState,
                                        until: UInt32) throws
    {
        guard s.Nr + s.maxSkip >= until, var ckr = s.CKr, let dhr = s.DHr else { return }
        while s.Nr < until {
            let (mk, next) = RatchetKDF.kdfCK(ck: ckr.sym)
            s.MKSKIPPED[SkippedKey(dhr: dhr.raw, n: s.Nr)] = WireKey(mk)
            if s.MKSKIPPED.count > s.maxCache { throw E2EEError.decryptionFailed }
            ckr = WireKey(next); s.Nr += 1
        }
        s.CKr = ckr
    }

    private static func dhRatchetStep(_ s: inout DoubleRatchetState,
                                      header: RatchetHeader) throws
    {
        s.PN = s.Ns; s.Ns = 0; s.Nr = 0
        let newDHr = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: header.dh)
        s.DHr = WireKey(newDHr)

        // First KDF_RK: derive receiving chain
        let dhOut1 = try s.DHs.priv().sharedSecretFromKeyAgreement(with: newDHr)
        let (rk1, ckr) = RatchetKDF.kdfRK(rk: s.RK.sym, dhOut: dhOut1)
        s.RK = WireKey(rk1); s.CKr = WireKey(ckr)

        // Generate new sending ratchet key pair
        let newDHs = Curve25519.KeyAgreement.PrivateKey()
        s.DHs = WireKey(newDHs)

        // Second KDF_RK: derive sending chain
        let dhOut2 = try newDHs.sharedSecretFromKeyAgreement(with: newDHr)
        let (rk2, cks) = RatchetKDF.kdfRK(rk: s.RK.sym, dhOut: dhOut2)
        s.RK = WireKey(rk2); s.CKs = WireKey(cks)
    }
}
```

---

## `Crypto/DoubleRatchetSession.swift`

```swift
import CryptoKit
import Foundation

/// Wraps DoubleRatchetState with atomic persistence. One session per partner.
final class DoubleRatchetSession {
    private(set) var state: DoubleRatchetState
    let sessionAD: Data
    private let persistence: SessionPersistence

    init(state: DoubleRatchetState, sessionAD: Data, persistence: SessionPersistence) {
        self.state       = state
        self.sessionAD   = sessionAD
        self.persistence = persistence
    }

    func encrypt(_ plaintext: Data) throws -> EncryptedPayload {
        var s = state
        let p = try DoubleRatchet.encrypt(state: &s, plaintext: plaintext,
                                          sessionAD: sessionAD)
        state = s
        try persistence.save(state: state)
        return p
    }

    func decrypt(_ payload: EncryptedPayload) throws -> Data {
        var s = state
        let pt = try DoubleRatchet.decrypt(state: &s, payload: payload,
                                           sessionAD: sessionAD)
        state = s
        try persistence.save(state: state)
        return pt
    }
}

// MARK: - Persistence
// SEK (session encryption key) lives in Keychain.
// Encrypted state blob lives on disk with iOS Data Protection.

final class SessionPersistence {
    private let partnerUsername: String
    private let sekStore = KeychainStore(service: "com.myapp.e2ee.sek")
    private let fileURL: URL

    init(partnerUsername: String) throws {
        self.partnerUsername = partnerUsername
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: true)
            .appendingPathComponent("RatchetSessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("\(partnerUsername).session")
    }

    private func sek() throws -> SymmetricKey {
        let acct = "sek.\(partnerUsername)"
        if let d = try? sekStore.get(account: acct) { return SymmetricKey(data: d) }
        let k = SymmetricKey(size: .bits256)
        try sekStore.set(k.withUnsafeBytes { Data($0) }, account: acct)
        return k
    }

    func save(state: DoubleRatchetState) throws {
        let k   = try sek()
        let pt  = try JSONEncoder().encode(state)
        let box = try AES.GCM.seal(pt, using: k, nonce: AES.GCM.Nonce())
        try box.combined!.write(to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func load() throws -> DoubleRatchetState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let blob = try Data(contentsOf: fileURL)
        let pt   = try AES.GCM.open(try AES.GCM.SealedBox(combined: blob), using: try sek())
        return try JSONDecoder().decode(DoubleRatchetState.self, from: pt)
    }

    func wipe() throws {
        try? FileManager.default.removeItem(at: fileURL)
        try sekStore.delete(account: "sek.\(partnerUsername)")
    }
}
```

---

## `Models/SyncModels.swift`

```swift
import Foundation

// MARK: - Sync batch (plaintext, encrypted before sending)

/// The plaintext that gets JSON-encoded then encrypted inside WireSyncEnvelope.
/// Contains only what the recipient needs to reconstruct the synced encounters.
///
/// NOT included:
///   - Built-in catalog types (predefined UUIDs 00000000-…) — recipient has them
///   - Both sync participants' SQLPartner records — both sides have each other locally
///   - Encounters not involving the sync partner
struct SyncBatch: Codable {
    // Core encounter data
    var encounters:                [SyncEncounter]
    var encounterPartners:         [SyncEncounterPartner]
    var encounterActivities:       [SyncEncounterActivity]
    var encounterProtectionMethods:[SyncEncounterProtectionMethod]

    // Third-party partners only (not Alice or Bob)
    var thirdPartyPartners:                 [SyncPartner]
    var thirdPartyPartnerAttributeValues:   [SyncPartnerAttributeValue]

    // Custom catalog types only (isBuiltIn == false)
    var customPositionTypes:        [SyncPositionType]
    var customActivityTypes:        [SyncActivityType]
    var customProtectionMethodTypes:[SyncProtectionMethodType]
    var customPartnerAttributeTypes:[SyncPartnerAttributeType]

    // Profile key — included only on first sync or after key rotation
    var senderProfileKey: Data?   // 32 raw bytes

    let senderUsername: String
    let sentAt: Date
}

// MARK: - Sync-safe encounter models (no SQLiteData dependencies)

struct SyncEncounter: Codable, Identifiable {
    let id: UUID
    var date: Date?
    var duration: TimeInterval
    var location: String
    var notes: String
    var rating: Int
    var reachedOrgasm: Bool
    var positionTypeId: UUID?
    var dateAdded: Date

    init(from sql: SQLEncounter) {
        id = sql.id; date = sql.date; duration = sql.duration
        location = sql.location; notes = sql.notes; rating = sql.rating
        reachedOrgasm = sql.reachedOrgasm; positionTypeId = sql.positionTypeId
        dateAdded = sql.dateAdded
    }
}

struct SyncEncounterPartner: Codable, Identifiable {
    let id: UUID
    var encounterId: UUID
    var partnerId: UUID
    var positionTypeId: UUID?
    var hadOrgasm: Bool

    init(from sql: SQLEncounterPartner) {
        id = sql.id; encounterId = sql.encounterId; partnerId = sql.partnerId
        positionTypeId = sql.positionTypeId; hadOrgasm = sql.hadOrgasm
    }
}

struct SyncEncounterActivity: Codable, Identifiable {
    let id: UUID; var encounterId: UUID; var activityTypeId: UUID
    init(from sql: EncounterActivity) {
        id = sql.id; encounterId = sql.encounterId; activityTypeId = sql.activityTypeId
    }
}

struct SyncEncounterProtectionMethod: Codable, Identifiable {
    let id: UUID; var encounterId: UUID; var protectionMethodId: UUID
    init(from sql: EncounterProtectionMethod) {
        id = sql.id; encounterId = sql.encounterId; protectionMethodId = sql.protectionMethodId
    }
}

struct SyncPartner: Codable, Identifiable {
    let id: UUID; var name: String; var notes: String
    var relationshipType: String; var dateMet: Date?; var dateAdded: Date
    init(from sql: SQLPartner) {
        id = sql.id; name = sql.name; notes = sql.notes
        relationshipType = sql.relationshipType.rawValue
        dateMet = sql.dateMet; dateAdded = sql.dateAdded
    }
}

struct SyncPartnerAttributeValue: Codable, Identifiable {
    let id: UUID; var partnerId: UUID; var attributeTypeId: UUID; var value: String
    init(from sql: SQLPartnerAttributeValue) {
        id = sql.id; partnerId = sql.partnerId
        attributeTypeId = sql.attributeTypeId; value = sql.value
    }
}

struct SyncPositionType: Codable, Identifiable {
    let id: UUID; var name: String; var icon: String; var sortOrder: Int
    init(from sql: SQLPositionType) {
        id = sql.id; name = sql.name; icon = sql.icon; sortOrder = sql.sortOrder
    }
}

struct SyncActivityType: Codable, Identifiable {
    let id: UUID; var name: String; var icon: String; var sortOrder: Int
    init(from sql: SQLActivityTypeEntity) {
        id = sql.id; name = sql.name; icon = sql.icon; sortOrder = sql.sortOrder
    }
}

struct SyncProtectionMethodType: Codable, Identifiable {
    let id: UUID; var name: String; var icon: String; var sortOrder: Int
    init(from sql: SQLProtectionMethodEntity) {
        id = sql.id; name = sql.name; icon = sql.icon; sortOrder = sql.sortOrder
    }
}

struct SyncPartnerAttributeType: Codable, Identifiable {
    let id: UUID; var name: String; var fieldType: String
    var icon: String; var sortOrder: Int; var enumChoices: String?
    init(from sql: SQLPartnerAttributeType) {
        id = sql.id; name = sql.name; fieldType = sql.fieldType
        icon = sql.icon; sortOrder = sql.sortOrder; enumChoices = sql.enumChoices
    }
}

// MARK: - Encounter graph (used for merge logic)

struct EncounterGraph {
    let encounter:      SyncEncounter
    let partnerRows:    [SyncEncounterPartner]
    let activityRows:   [SyncEncounterActivity]
    let protectionRows: [SyncEncounterProtectionMethod]
}
```

---

## `Services/APIClient.swift`

```swift
import Foundation

struct PartnerRecord: Codable, Identifiable {
    let id: String
    let partnerUsername: String
    let partnerID: String
    let status: String
    let safetyNumbersVerified: Bool
    let isRequester: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case partnerUsername       = "partner_username"
        case partnerID             = "partner_id"
        case status
        case safetyNumbersVerified = "safety_numbers_verified"
        case isRequester           = "is_requester"
    }
}

struct SyncPayloadRecord: Codable {
    let id: String; let messageType: String; let phase: Int
    let payload: String; let created: String
    enum CodingKeys: String, CodingKey {
        case id; case messageType = "message_type"
        case phase; case payload; case created
    }
}

struct EmptyResp: Codable {}
struct IDResp:    Codable { let id: String }

final class APIClient {
    static let shared = APIClient()
    var baseURL   = URL(string: "https://api.example.com")!
    var authToken: String?

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
        if let t = authToken { r.addValue(t, forHTTPHeaderField: "Authorization") }
        if let b = body { r.httpBody = try JSONEncoder().encode(b) }
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) == true else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Registration
    func sendCode(phone: String) async throws {
        struct B: Encodable { let phone: String }
        let _: EmptyResp = try await post("/api/auth/send-code", body: B(phone: phone))
    }
    func verifyCode(phone: String, code: String) async throws -> VerifyResp {
        struct B: Encodable { let phone: String; let code: String }
        return try await post("/api/auth/verify-code", body: B(phone: phone, code: code))
    }
    func checkUsername(_ username: String) async throws -> Bool {
        struct R: Decodable { let available: Bool }
        let r: R = try await get("/api/auth/check-username?username=\(username)")
        return r.available
    }

    // MARK: - Key bundle
    func fetchKeyBundle(username: String) async throws -> KeyBundle {
        try await get("/api/e2ee/users/\(username)/keys")
    }

    // MARK: - Profile
    func fetchProfile(username: String) async throws -> ProfileResp {
        try await get("/api/e2ee/profile/\(username)")
    }

    // MARK: - Partners
    func requestPartner(username: String) async throws -> IDResp {
        struct B: Encodable { let username: String }
        return try await post("/api/e2ee/partners/request", body: B(username: username))
    }
    func listPartners() async throws -> [PartnerRecord] {
        try await get("/api/e2ee/partners")
    }
    func acceptPartner(id: String) async throws {
        let _: EmptyResp = try await post("/api/e2ee/partners/\(id)/accept", body: EmptyResp())
    }
    func markPartnerVerified(id: String) async throws {
        let _: EmptyResp = try await post("/api/e2ee/partners/\(id)/verified", body: EmptyResp())
    }

    // MARK: - Sync
    func syncPush(recipientUsername: String, messageType: String,
                  phase: Int, payload: String) async throws
    {
        struct B: Encodable {
            let recipient_username: String; let message_type: String
            let phase: Int; let payload: String
        }
        let _: IDResp = try await post("/api/e2ee/sync/push",
            body: B(recipient_username: recipientUsername,
                    message_type: messageType, phase: phase, payload: payload))
    }
    func fetchIncoming(partnerUsername: String) async throws -> [SyncPayloadRecord] {
        try await get("/api/e2ee/sync/incoming/\(partnerUsername)")
    }
}

struct VerifyResp: Decodable {
    let token: String; let userID: String; let isNewUser: Bool
    enum CodingKeys: String, CodingKey {
        case token; case userID = "user_id"; case isNewUser = "is_new_user"
    }
}

struct ProfileResp: Decodable {
    let encryptedBlob: String; let nonce: String; let version: Int
    enum CodingKeys: String, CodingKey {
        case encryptedBlob = "encrypted_blob"; case nonce; case version
    }
}
```

---

## `Services/RegistrationService.swift`

```swift
import Foundation

final class RegistrationService {
    static let shared = RegistrationService()
    private let api = APIClient.shared
    private let km  = E2EEKeyManager.shared

    func sendCode(phone: String) async throws {
        try await api.sendCode(phone: phone)
    }

    func verifyCode(phone: String, code: String) async throws -> VerifyResp {
        let resp = try await api.verifyCode(phone: phone, code: code)
        api.authToken = resp.token
        return resp
    }

    struct CompletionInput {
        let username: String; let displayName: String; let avatarJpeg: Data?
    }

    func completeRegistration(_ input: CompletionInput) async throws {
        // 1. Generate keys
        let bundle = try km.installAndBuildRegistrationBundle(opkCount: 100)

        // 2. Encrypt profile
        let profileKey = try ProfileKeyManager.shared.profileKey()
        let profile    = PlaintextProfile(displayName: input.displayName,
                                          avatarJpeg: input.avatarJpeg)
        let (blob, nonce) = try ProfileCrypto.encrypt(profile, key: profileKey)

        // 3. Single atomic POST
        struct Body: Encodable {
            let username: String
            let encrypted_blob: String; let nonce: String
            let identity_signing_pub: String; let identity_agreement_pub: String
            let signed_prekey_id: UInt32; let signed_prekey_pub: String
            let signed_prekey_sig: String
            let one_time_prekeys: [[String: String]]
        }
        let opks = bundle.oneTimePrekeys.map {
            ["prekey_id": String($0.id), "public_key": $0.publicKey]
        }
        let _: EmptyResp = try await api.post("/api/auth/complete", body: Body(
            username:               input.username,
            encrypted_blob:         blob,
            nonce:                  nonce,
            identity_signing_pub:   bundle.identitySigningPub,
            identity_agreement_pub: bundle.identityAgreementPub,
            signed_prekey_id:       bundle.signedPrekeyId,
            signed_prekey_pub:      bundle.signedPrekeyPub,
            signed_prekey_sig:      bundle.signedPrekeySig,
            one_time_prekeys:       opks
        ))

        UserDefaults.standard.set(input.username, forKey: "username")
    }

    func restoreSession(token: String) {
        api.authToken = token
    }
}
```

---

## `Services/SyncService.swift`

```swift
import CryptoKit
import Foundation

final class SyncService {
    static let shared = SyncService()
    private let api   = APIClient.shared
    private let km    = E2EEKeyManager.shared
    private let pins  = IdentityPinStore.shared

    /// Two encounters are considered the same event if duration matches within
    /// 60 seconds, and they share the same activities, protection methods,
    /// and participant positions.
    private func isConflict(_ a: EncounterGraph, _ b: EncounterGraph) -> Bool {
        guard abs(a.encounter.duration - b.encounter.duration) <= 60 else { return false }
        let aAct = Set(a.activityRows.map(\.activityTypeId))
        let bAct = Set(b.activityRows.map(\.activityTypeId))
        guard aAct == bAct else { return false }
        let aPro = Set(a.protectionRows.map(\.protectionMethodId))
        let bPro = Set(b.protectionRows.map(\.protectionMethodId))
        guard aPro == bPro else { return false }
        let aPos = a.partnerRows.map { $0.positionTypeId?.uuidString ?? "nil" }.sorted()
        let bPos = b.partnerRows.map { $0.positionTypeId?.uuidString ?? "nil" }.sorted()
        return aPos == bPos
    }

    func merge(mine: [EncounterGraph], theirs: [EncounterGraph],
               initiatorWins: Bool) -> [EncounterGraph]
    {
        var result = mine
        for enc in theirs {
            if let idx = result.firstIndex(where: { isConflict($0, enc) }) {
                if !initiatorWins { result[idx] = enc } // theirs wins
            } else {
                result.append(enc)
            }
        }
        return result
    }

    // MARK: - Initiate sync (Alice / the user who taps "Sync")

    func syncWithPartner(
        myUserID: UUID, syncPartnerID: UUID,
        allEncounters: [SQLEncounter],
        encounterPartners: [SQLEncounterPartner],
        encounterActivities: [EncounterActivity],
        encounterProtectionMethods: [EncounterProtectionMethod],
        allPartners: [SQLPartner],
        allPartnerAttributeValues: [SQLPartnerAttributeValue],
        allPositionTypes: [SQLPositionType],
        allActivityTypes: [SQLActivityTypeEntity],
        allProtectionMethodTypes: [SQLProtectionMethodEntity],
        allPartnerAttributeTypes: [SQLPartnerAttributeType],
        partnerUsername: String,
        isFirstSync: Bool
    ) async throws -> [EncounterGraph] {

        let bundle    = try await api.fetchKeyBundle(username: partnerUsername)
        try pins.checkOrPin(username: partnerUsername,
                            signingPub:   bundle.identitySigningPub,
                            agreementPub: bundle.identityAgreementPub)

        let myIK      = try km.identityAgreementKey().publicKey.rawRepresentation
        let sessionAD = buildSessionAD(myIK: myIK, theirIK: bundle.identityAgreementPub)
        let (session, msgType, x3dhFields) = try await resolveSession(
            bundle: bundle, partnerUsername: partnerUsername, sessionAD: sessionAD)

        let myBatch = SyncBatchBuilder.build(
            myUserID: myUserID, syncPartnerID: syncPartnerID,
            allEncounters: allEncounters, encounterPartners: encounterPartners,
            encounterActivities: encounterActivities,
            encounterProtectionMethods: encounterProtectionMethods,
            allPartners: allPartners, allPartnerAttributeValues: allPartnerAttributeValues,
            allPositionTypes: allPositionTypes, allActivityTypes: allActivityTypes,
            allProtectionMethodTypes: allProtectionMethodTypes,
            allPartnerAttributeTypes: allPartnerAttributeTypes,
            senderUsername: currentUsername(),
            profileKeyData: isFirstSync ? try? ProfileKeyManager.shared.profileKeyRawBytes() : nil
        )

        let batchJSON = try JSONEncoder().encode(myBatch)
        let encrypted = try session.encrypt(batchJSON)
        let mySignPub = try km.identitySigningKey().publicKey.rawRepresentation
        let envelope  = WireSyncEnvelope(
            type: msgType, senderIdentityAgreementPub: myIK,
            senderIdentitySigningPub: mySignPub, ratchet: encrypted,
            ephemeralPub: x3dhFields?.ephemeralPub,
            usedSignedPrekeyID: x3dhFields?.usedSPKID,
            usedOneTimePrekeyID: x3dhFields?.usedOPKID)

        try await api.syncPush(
            recipientUsername: partnerUsername, messageType: msgType.rawValue,
            phase: 1, payload: try JSONEncoder().encode(envelope).base64EncodedString())

        // Wait for phase-2 response then merge
        let theirRecord = try await waitForPhase2(from: partnerUsername)
        let theirBatch  = try decryptIncoming(record: theirRecord,
                                              partnerUsername: partnerUsername,
                                              sessionAD: sessionAD)

        // Cache partner's profile key if included
        if let keyData = theirBatch.senderProfileKey {
            try? ProfileKeyManager.shared.cachePartnerKey(
                SymmetricKey(data: keyData), forUsername: partnerUsername)
        }

        return merge(mine: buildGraphs(from: myBatch),
                     theirs: buildGraphs(from: theirBatch), initiatorWins: true)
    }

    // MARK: - Respond to incoming sync (Bob)

    func respondToSync(
        myUserID: UUID, syncPartnerID: UUID,
        allEncounters: [SQLEncounter],
        encounterPartners: [SQLEncounterPartner],
        encounterActivities: [EncounterActivity],
        encounterProtectionMethods: [EncounterProtectionMethod],
        allPartners: [SQLPartner],
        allPartnerAttributeValues: [SQLPartnerAttributeValue],
        allPositionTypes: [SQLPositionType],
        allActivityTypes: [SQLActivityTypeEntity],
        allProtectionMethodTypes: [SQLProtectionMethodEntity],
        allPartnerAttributeTypes: [SQLPartnerAttributeType],
        partnerUsername: String,
        isFirstSync: Bool
    ) async throws -> [EncounterGraph] {

        let incoming = try await api.fetchIncoming(partnerUsername: partnerUsername)
        guard let phase1 = incoming.first(where: { $0.phase == 1 }) else {
            throw E2EEError.noSession
        }

        let myIK       = try km.identityAgreementKey().publicKey.rawRepresentation
        let theirBatch = try await decryptPhase1(record: phase1,
                                                  partnerUsername: partnerUsername,
                                                  myIK: myIK)
        if let keyData = theirBatch.senderProfileKey {
            try? ProfileKeyManager.shared.cachePartnerKey(
                SymmetricKey(data: keyData), forUsername: partnerUsername)
        }

        let myBatch = SyncBatchBuilder.build(
            myUserID: myUserID, syncPartnerID: syncPartnerID,
            allEncounters: allEncounters, encounterPartners: encounterPartners,
            encounterActivities: encounterActivities,
            encounterProtectionMethods: encounterProtectionMethods,
            allPartners: allPartners, allPartnerAttributeValues: allPartnerAttributeValues,
            allPositionTypes: allPositionTypes, allActivityTypes: allActivityTypes,
            allProtectionMethodTypes: allProtectionMethodTypes,
            allPartnerAttributeTypes: allPartnerAttributeTypes,
            senderUsername: currentUsername(),
            profileKeyData: isFirstSync ? try? ProfileKeyManager.shared.profileKeyRawBytes() : nil
        )

        let bundle    = try await api.fetchKeyBundle(username: partnerUsername)
        let sessionAD = buildSessionAD(myIK: myIK, theirIK: bundle.identityAgreementPub)
        let (session, msgType, x3dhFields) = try await resolveSession(
            bundle: bundle, partnerUsername: partnerUsername, sessionAD: sessionAD)

        let encrypted = try session.encrypt(try JSONEncoder().encode(myBatch))
        let mySignPub = try km.identitySigningKey().publicKey.rawRepresentation
        let envelope  = WireSyncEnvelope(
            type: msgType, senderIdentityAgreementPub: myIK,
            senderIdentitySigningPub: mySignPub, ratchet: encrypted,
            ephemeralPub: x3dhFields?.ephemeralPub,
            usedSignedPrekeyID: x3dhFields?.usedSPKID,
            usedOneTimePrekeyID: x3dhFields?.usedOPKID)

        try await api.syncPush(
            recipientUsername: partnerUsername, messageType: msgType.rawValue,
            phase: 2, payload: try JSONEncoder().encode(envelope).base64EncodedString())

        return merge(mine: buildGraphs(from: myBatch),
                     theirs: buildGraphs(from: theirBatch), initiatorWins: false)
    }

    // MARK: - Session resolution

    private struct X3DHFields {
        let ephemeralPub: Data; let usedSPKID: UInt32; let usedOPKID: UInt32?
    }

    private func resolveSession(bundle: KeyBundle, partnerUsername: String,
                                sessionAD: Data) async throws
        -> (DoubleRatchetSession, WireSyncEnvelope.MessageType, X3DHFields?)
    {
        let persistence = try SessionPersistence(partnerUsername: partnerUsername)
        if let existing = try persistence.load() {
            return (DoubleRatchetSession(state: existing, sessionAD: sessionAD,
                                         persistence: persistence), .ratchet, nil)
        }
        let x3dh   = try X3DH.initiate(myAgreementKey: km.identityAgreementKey(),
                                        bundle: bundle)
        let spkPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: bundle.signedPrekeyPub)
        let state  = try DoubleRatchet.initAlice(sk: x3dh.sharedSecret, bobSPKPub: spkPub)
        let session = DoubleRatchetSession(state: state, sessionAD: sessionAD,
                                           persistence: persistence)
        return (session, .x3dhInitial,
                X3DHFields(ephemeralPub: x3dh.ephemeralPublicKey,
                           usedSPKID: x3dh.usedSPKID, usedOPKID: x3dh.usedOPKID))
    }

    // MARK: - Decrypt helpers

    private func decryptPhase1(record: SyncPayloadRecord, partnerUsername: String,
                               myIK: Data) async throws -> SyncBatch
    {
        guard let envData = Data(base64Encoded: record.payload) else {
            throw E2EEError.decryptionFailed
        }
        let envelope  = try JSONDecoder().decode(WireSyncEnvelope.self, from: envData)
        let sessionAD = buildSessionAD(myIK: myIK, theirIK: envelope.senderIdentityAgreementPub)
        let persistence = try SessionPersistence(partnerUsername: partnerUsername)
        let session: DoubleRatchetSession

        if envelope.type == .x3dhInitial {
            guard let eph   = envelope.ephemeralPub,
                  let spkID = envelope.usedSignedPrekeyID else { throw E2EEError.decryptionFailed }
            let sk = try X3DH.respond(
                myIdentityKey:     km.identityAgreementKey(),
                mySignedPrekey:    km.signedPrekey(id: spkID),
                myOneTimePrekey:   envelope.usedOneTimePrekeyID.flatMap {
                    try? km.oneTimePrekey(id: $0)
                },
                theirIdentityPub:  envelope.senderIdentityAgreementPub,
                theirEphemeralPub: eph)
            if let id = envelope.usedOneTimePrekeyID { km.deleteOneTimePrekey(id: id) }
            let bobSPKPriv = try km.signedPrekey(id: spkID)
            let state = DoubleRatchet.initBob(sk: sk, bobSPKPriv: bobSPKPriv)
            session = DoubleRatchetSession(state: state, sessionAD: sessionAD,
                                           persistence: persistence)
        } else {
            guard let existing = try persistence.load() else { throw E2EEError.noSession }
            session = DoubleRatchetSession(state: existing, sessionAD: sessionAD,
                                           persistence: persistence)
        }
        return try JSONDecoder().decode(SyncBatch.self, from: try session.decrypt(envelope.ratchet))
    }

    private func decryptIncoming(record: SyncPayloadRecord, partnerUsername: String,
                                 sessionAD: Data) throws -> SyncBatch
    {
        guard let envData = Data(base64Encoded: record.payload) else {
            throw E2EEError.decryptionFailed
        }
        let envelope    = try JSONDecoder().decode(WireSyncEnvelope.self, from: envData)
        let persistence = try SessionPersistence(partnerUsername: partnerUsername)
        guard let existing = try persistence.load() else { throw E2EEError.noSession }
        let session = DoubleRatchetSession(state: existing, sessionAD: sessionAD,
                                           persistence: persistence)
        return try JSONDecoder().decode(SyncBatch.self, from: try session.decrypt(envelope.ratchet))
    }

    // MARK: - Helpers

    private func buildGraphs(from batch: SyncBatch) -> [EncounterGraph] {
        batch.encounters.map { enc in
            EncounterGraph(
                encounter:      enc,
                partnerRows:    batch.encounterPartners.filter    { $0.encounterId == enc.id },
                activityRows:   batch.encounterActivities.filter  { $0.encounterId == enc.id },
                protectionRows: batch.encounterProtectionMethods.filter { $0.encounterId == enc.id }
            )
        }
    }

    private func buildSessionAD(myIK: Data, theirIK: Data) -> Data {
        myIK <= theirIK ? myIK + theirIK : theirIK + myIK
    }

    private func currentUsername() -> String {
        UserDefaults.standard.string(forKey: "username") ?? ""
    }

    private func waitForPhase2(from partner: String, attempts: Int = 20,
                               delay: TimeInterval = 3) async throws -> SyncPayloadRecord
    {
        for _ in 0..<attempts {
            if let p2 = try await api.fetchIncoming(partnerUsername: partner)
                .first(where: { $0.phase == 2 }) { return p2 }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        throw E2EEError.noSession
    }
}

// MARK: - SyncBatchBuilder

struct SyncBatchBuilder {
    static func build(
        myUserID: UUID, syncPartnerID: UUID,
        allEncounters: [SQLEncounter],
        encounterPartners: [SQLEncounterPartner],
        encounterActivities: [EncounterActivity],
        encounterProtectionMethods: [EncounterProtectionMethod],
        allPartners: [SQLPartner],
        allPartnerAttributeValues: [SQLPartnerAttributeValue],
        allPositionTypes: [SQLPositionType],
        allActivityTypes: [SQLActivityTypeEntity],
        allProtectionMethodTypes: [SQLProtectionMethodEntity],
        allPartnerAttributeTypes: [SQLPartnerAttributeType],
        senderUsername: String,
        profileKeyData: Data?
    ) -> SyncBatch {

        // Encounters involving sync partner
        let relevantIDs = Set(encounterPartners
            .filter { $0.partnerId == syncPartnerID }
            .map(\.encounterId))
        let relEnc = allEncounters.filter { relevantIDs.contains($0.id) }
        let relEP  = encounterPartners.filter { relevantIDs.contains($0.encounterId) }
        let relEA  = encounterActivities.filter { relevantIDs.contains($0.encounterId) }
        let relEPM = encounterProtectionMethods.filter { relevantIDs.contains($0.encounterId) }

        // Third-party partners (exclude both sync participants)
        let participantIDs  = Set(relEP.map(\.partnerId))
        let excluded: Set<UUID> = [myUserID, syncPartnerID]
        let thirdPartyIDs   = participantIDs.subtracting(excluded)
        let thirdParty      = allPartners.filter { thirdPartyIDs.contains($0.id) }
        let thirdPartyAttrs = allPartnerAttributeValues.filter { thirdPartyIDs.contains($0.partnerId) }

        // Referenced catalog type IDs
        var posIDs = Set(relEnc.compactMap(\.positionTypeId))
        posIDs.formUnion(relEP.compactMap(\.positionTypeId))
        let actIDs  = Set(relEA.map(\.activityTypeId))
        let proIDs  = Set(relEPM.map(\.protectionMethodId))
        let attrIDs = Set(thirdPartyAttrs.map(\.attributeTypeId))

        // Custom types only (skip built-ins)
        let customPos  = allPositionTypes.filter       { !$0.isBuiltIn && posIDs.contains($0.id) }
        let customAct  = allActivityTypes.filter       { !$0.isBuiltIn && actIDs.contains($0.id) }
        let customPro  = allProtectionMethodTypes.filter { !$0.isBuiltIn && proIDs.contains($0.id) }
        let customAttr = allPartnerAttributeTypes.filter { !$0.isBuiltIn && attrIDs.contains($0.id) }

        return SyncBatch(
            encounters:                      relEnc.map { SyncEncounter(from: $0) },
            encounterPartners:               relEP.map  { SyncEncounterPartner(from: $0) },
            encounterActivities:             relEA.map  { SyncEncounterActivity(from: $0) },
            encounterProtectionMethods:      relEPM.map { SyncEncounterProtectionMethod(from: $0) },
            thirdPartyPartners:              thirdParty.map      { SyncPartner(from: $0) },
            thirdPartyPartnerAttributeValues: thirdPartyAttrs.map { SyncPartnerAttributeValue(from: $0) },
            customPositionTypes:             customPos.map  { SyncPositionType(from: $0) },
            customActivityTypes:             customAct.map  { SyncActivityType(from: $0) },
            customProtectionMethodTypes:     customPro.map  { SyncProtectionMethodType(from: $0) },
            customPartnerAttributeTypes:     customAttr.map { SyncPartnerAttributeType(from: $0) },
            senderProfileKey:                profileKeyData,
            senderUsername:                  senderUsername,
            sentAt:                          Date()
        )
    }
}
```

---

## `Views/Registration/RegistrationView.swift`

```swift
import SwiftUI

struct RegistrationView: View {
    @State private var step: Step = .phone

    enum Step {
        case phone
        case verify(phone: String)
        case profileSetup
        case done
    }

    var body: some View {
        switch step {
        case .phone:
            PhoneEntryView { step = .verify(phone: $0) }
        case .verify(let phone):
            CodeVerifyView(phone: phone) { resp in
                if resp.isNewUser { step = .profileSetup }
                else { RegistrationService.shared.restoreSession(token: resp.token); step = .done }
            }
        case .profileSetup:
            ProfileSetupView { step = .done }
        case .done:
            EmptyView() // navigate to main app
        }
    }
}
```

---

## `Views/Registration/PhoneEntryView.swift`

```swift
import SwiftUI

struct PhoneEntryView: View {
    let onSent: (String) -> Void
    @State private var phone = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Enter your phone number").font(.title2.bold())
                Text("We'll send a one-time code. Your number is never stored on our servers.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .font(.subheadline).padding(.horizontal)
            }

            TextField("+1 (555) 000-0000", text: $phone)
                .keyboardType(.phonePad).textContentType(.telephoneNumber)
                .font(.title3).multilineTextAlignment(.center)
                .padding().background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)

            if let e = error { Text(e).foregroundStyle(.red).font(.caption) }

            Button(action: send) {
                isLoading ? AnyView(ProgressView())
                          : AnyView(Text("Send Code").font(.headline).frame(maxWidth: .infinity))
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .padding(.horizontal).disabled(phone.count < 8 || isLoading)
        }
        .padding()
    }

    private func send() {
        isLoading = true; error = nil
        let e164 = normaliseToE164(phone)
        Task {
            do { try await RegistrationService.shared.sendCode(phone: e164); onSent(e164) }
            catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }

    private func normaliseToE164(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        return digits.hasPrefix("1") ? "+\(digits)" : "+1\(digits)"
    }
}
```

---

## `Views/Registration/CodeVerifyView.swift`

```swift
import SwiftUI

struct CodeVerifyView: View {
    let phone: String
    let onVerified: (VerifyResp) -> Void
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var resendCooldown = 30
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Enter the code").font(.title2.bold())
                Text("Sent to \(phone)").foregroundStyle(.secondary).font(.subheadline)
            }

            TextField("000000", text: $code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .onChange(of: code) { _, new in if new.count == 6 { verify() } }

            if let e = error { Text(e).foregroundStyle(.red).font(.caption) }

            Button(isLoading ? "" : "Verify") { verify() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(code.count != 6 || isLoading)

            Button(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend code") {
                resend()
            }
            .foregroundStyle(resendCooldown > 0 ? .secondary : .blue)
            .disabled(resendCooldown > 0)
        }
        .padding()
        .onAppear { startCooldown() }
        .onDisappear { timer?.invalidate() }
    }

    private func verify() {
        isLoading = true; error = nil
        Task {
            do { onVerified(try await RegistrationService.shared.verifyCode(phone: phone, code: code)) }
            catch { self.error = "Incorrect code. Please try again."; self.code = "" }
            isLoading = false
        }
    }

    private func resend() {
        Task { try? await RegistrationService.shared.sendCode(phone: phone); startCooldown() }
    }

    private func startCooldown() {
        resendCooldown = 30
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if resendCooldown > 0 { resendCooldown -= 1 } else { t.invalidate() }
        }
    }
}
```

---

## `Views/Registration/ProfileSetupView.swift`

```swift
import PhotosUI
import SwiftUI

struct ProfileSetupView: View {
    let onComplete: () -> Void
    @State private var username    = ""
    @State private var displayName = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading   = false
    @State private var error: String?
    @State private var usernameAvailable: Bool?
    @State private var checkTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Set up your profile").font(.title2.bold())
                Text("Your display name and photo are end-to-end encrypted — only partners you sync with can see them.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .font(.subheadline).padding(.horizontal)

                PhotosPicker(selection: $avatarItem, matching: .images) {
                    Group {
                        if let img = avatarImage {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill").resizable().foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100).clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                .onChange(of: avatarItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img  = UIImage(data: data) { avatarImage = img }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Display name").font(.caption).foregroundStyle(.secondary)
                    TextField("Your name", text: $displayName)
                        .textContentType(.name).padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("@").foregroundStyle(.secondary)
                        TextField("username", text: $username)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .onChange(of: username) { _, new in checkUsername(new) }
                        Spacer()
                        if let avail = usernameAvailable {
                            Image(systemName: avail ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(avail ? .green : .red)
                        }
                    }
                    .padding(12).background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("3–32 characters. Letters, numbers, _ . - only.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }.padding(.horizontal)

                if let e = error { Text(e).foregroundStyle(.red).font(.caption) }

                Button(action: complete) {
                    isLoading ? AnyView(ProgressView())
                              : AnyView(Text("Create Account").font(.headline).frame(maxWidth: .infinity))
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .padding(.horizontal).disabled(!canSubmit)
            }
            .padding(.vertical, 32)
        }
    }

    private var canSubmit: Bool {
        !displayName.isEmpty && username.count >= 3 && usernameAvailable == true && !isLoading
    }

    private func checkUsername(_ name: String) {
        checkTask?.cancel(); usernameAvailable = nil
        guard name.count >= 3 else { return }
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            usernameAvailable = (try? await APIClient.shared.checkUsername(name)) ?? false
        }
    }

    private func complete() {
        isLoading = true; error = nil
        Task {
            do {
                try await RegistrationService.shared.completeRegistration(.init(
                    username:    username,
                    displayName: displayName,
                    avatarJpeg:  avatarImage?.jpegData(compressionQuality: 0.7)))
                onComplete()
            } catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }
}
```

---

## `Views/Main/AddPartnerView.swift`

```swift
import SwiftUI

struct AddPartnerView: View {
    @State private var username = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var didSend = false

    var body: some View {
        Form {
            Section("Find partner by username") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            if let e = error { Section { Text(e).foregroundStyle(.red).font(.caption) } }
            Section {
                Button(action: send) {
                    isLoading ? AnyView(ProgressView()) : AnyView(Text("Send Partner Request"))
                }.disabled(username.isEmpty || isLoading)
            }
        }
        .navigationTitle("Add Partner")
        .alert("Request sent!", isPresented: $didSend) { Button("OK") {} } message: {
            Text("Once \(username) accepts, tap Sync to merge your encounter histories.")
        }
    }

    private func send() {
        isLoading = true; error = nil
        Task {
            do { _ = try await APIClient.shared.requestPartner(username: username); didSend = true }
            catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }
}
```

---

## `Views/Main/PartnersListView.swift`

```swift
import SwiftUI

struct PartnersListView: View {
    @State private var partners:      [PartnerRecord] = []
    @State private var verifyTarget:  PartnerRecord?
    @State private var syncTarget:    PartnerRecord?

    var body: some View {
        List(partners) { partner in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.partnerUsername).font(.headline)
                    HStack(spacing: 4) {
                        Text(partner.status.capitalized).font(.caption).foregroundStyle(.secondary)
                        if partner.safetyNumbersVerified {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green).font(.caption)
                        }
                    }
                }
                Spacer()
                if partner.status == "active" {
                    HStack(spacing: 6) {
                        if !partner.safetyNumbersVerified {
                            Button("Verify") { verifyTarget = partner }
                                .buttonStyle(.bordered).font(.caption)
                        }
                        Button("Sync") { syncTarget = partner }
                            .buttonStyle(.borderedProminent).font(.caption)
                    }
                } else if partner.status == "pending" && !partner.isRequester {
                    Button("Accept") { accept(partner) }
                        .buttonStyle(.borderedProminent).font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Partners")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddPartnerView()) { Image(systemName: "plus") }
            }
        }
        .task { partners = (try? await APIClient.shared.listPartners()) ?? [] }
        .sheet(item: $verifyTarget) { SafetyNumberView(partner: $0) }
        .sheet(item: $syncTarget)   { SyncView(partner: $0) }
    }

    private func accept(_ partner: PartnerRecord) {
        Task {
            try? await APIClient.shared.acceptPartner(id: partner.id)
            partners = (try? await APIClient.shared.listPartners()) ?? []
        }
    }
}
```

---

## `Views/Main/SafetyNumberView.swift`

```swift
import SwiftUI

struct SafetyNumberView: View {
    let partner: PartnerRecord
    @Environment(\.dismiss) private var dismiss
    @State private var safetyNumber: String?
    @State private var isLoading = true
    @State private var verified  = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Verify \(partner.partnerUsername)").font(.title2.bold())
                Text("Compare this 60-digit code with your partner in person. If it matches, tap "Mark as Verified".")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)

                if isLoading { ProgressView() }
                else if let num = safetyNumber {
                    let groups = stride(from: 0, to: 60, by: 5).map { i -> String in
                        let s = num.index(num.startIndex, offsetBy: i)
                        let e = num.index(s, offsetBy: 5)
                        return String(num[s..<e])
                    }
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3),
                              spacing: 12) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                            Text(g)
                                .font(.system(.title3, design: .monospaced).bold())
                                .padding(8).frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(.horizontal)
                }

                if verified {
                    Label("Verified", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green).font(.headline)
                } else {
                    Button("Mark as Verified") { markVerified() }
                        .buttonStyle(.borderedProminent).disabled(isLoading)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await compute() }
        }
    }

    private func compute() async {
        isLoading = true; defer { isLoading = false }
        guard let bundle    = try? await APIClient.shared.fetchKeyBundle(username: partner.partnerUsername),
              let mySignKey = try? E2EEKeyManager.shared.identitySigningKey() else { return }
        let me = UserDefaults.standard.string(forKey: "username") ?? ""
        safetyNumber = SafetyNumber.combined(
            localIK:        mySignKey.publicKey.rawRepresentation,
            localUsername:  me,
            remoteIK:       bundle.identitySigningPub,
            remoteUsername: partner.partnerUsername)
    }

    private func markVerified() {
        Task {
            try? await APIClient.shared.markPartnerVerified(id: partner.id)
            try? IdentityPinStore.shared.markVerified(partner.partnerUsername)
            verified = true
        }
    }
}
```

---

## `Views/Main/SyncView.swift`

```swift
import SwiftUI

struct SyncView: View {
    let partner: PartnerRecord
    @Environment(\.dismiss) private var dismiss

    enum SyncPhase { case idle; case syncing; case done(Int); case failed(String) }
    @State private var phase: SyncPhase = .idle

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                switch phase {
                case .idle:
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 64)).foregroundStyle(.blue)
                    Text("Sync with \(partner.partnerUsername)").font(.title2.bold())
                    Text("Your encounter histories will be merged. On any conflicts, your version will be kept.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
                    if !partner.safetyNumbersVerified {
                        Label("Consider verifying safety numbers first",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange).padding(.horizontal)
                    }
                    Button("Start Sync", action: start)
                        .buttonStyle(.borderedProminent).font(.headline)

                case .syncing:
                    ProgressView().progressViewStyle(.circular).scaleEffect(1.5)
                    Text("Syncing…").font(.title3.bold())
                    Text("Encrypting and exchanging encounter histories.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)

                case .done(let count):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64)).foregroundStyle(.green)
                    Text("Sync complete").font(.title2.bold())
                    Text("\(count) encounters in your shared history.").foregroundStyle(.secondary)
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent)

                case .failed(let msg):
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 64)).foregroundStyle(.red)
                    Text("Sync failed").font(.title2.bold())
                    Text(msg).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
                    Button("Try Again", action: start).buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func start() {
        phase = .syncing
        Task {
            do {
                // Replace these with your actual SQLiteData DB calls.
                let allEncounters         = loadAll(SQLEncounter.self)
                let encounterPartners     = loadAll(SQLEncounterPartner.self)
                let encounterActivities   = loadAll(EncounterActivity.self)
                let encounterProtections  = loadAll(EncounterProtectionMethod.self)
                let allPartners           = loadAll(SQLPartner.self)
                let allAttrValues         = loadAll(SQLPartnerAttributeValue.self)
                let allPositionTypes      = loadAll(SQLPositionType.self)
                let allActivityTypes      = loadAll(SQLActivityTypeEntity.self)
                let allProtectionTypes    = loadAll(SQLProtectionMethodEntity.self)
                let allAttrTypes          = loadAll(SQLPartnerAttributeType.self)

                // myUserID = your own SQLPartner.id (the row that represents "me")
                // partner.localPartnerID = SQLPartner.id for this partner
                // (store this mapping when the partner relationship is established)
                let merged = try await SyncService.shared.syncWithPartner(
                    myUserID:                  myUserID,
                    syncPartnerID:             partner.localPartnerID,
                    allEncounters:             allEncounters,
                    encounterPartners:         encounterPartners,
                    encounterActivities:       encounterActivities,
                    encounterProtectionMethods: encounterProtections,
                    allPartners:               allPartners,
                    allPartnerAttributeValues: allAttrValues,
                    allPositionTypes:          allPositionTypes,
                    allActivityTypes:          allActivityTypes,
                    allProtectionMethodTypes:  allProtectionTypes,
                    allPartnerAttributeTypes:  allAttrTypes,
                    partnerUsername:           partner.partnerUsername,
                    isFirstSync:               !hasExistingSession(for: partner.partnerUsername)
                )

                // Apply merged graphs to local DB (replace with your upsert calls)
                applyMerged(merged)

                phase = .done(merged.count)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - DB stubs (replace with your SQLiteData calls)

    private var myUserID: UUID { UUID() /* load from user session */ }

    private func loadAll<T>(_ type: T.Type) -> [T] { [] }

    private func hasExistingSession(for username: String) -> Bool {
        (try? SessionPersistence(partnerUsername: username).load()) != nil
    }

    private func applyMerged(_ graphs: [EncounterGraph]) {
        // Upsert encounters, junction rows, third-party partners,
        // and custom catalog types into your local SQLite DB.
    }
}
```
