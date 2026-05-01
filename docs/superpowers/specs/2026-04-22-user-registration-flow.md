# User Registration Flow — Design Spec

**Date:** 2026-04-22
**Status:** Approved

## Overview

Build the phone-number-to-username registration flow, surfaced under Settings > Experiments > User Registration, gated by the `settings.more.experiments.userRegistration` feature flag. The flow is fully end-to-end: real SMS verification via Twilio, real CryptoKit key generation, AES-GCM profile encryption, and an atomic upload to the dev backend.

**API base URL:** `https://dev.coitalcomra.de`
**Feature flags API:** `https://dev.coitalcomra.de/api/feature-flags`

---

## Scope

**In scope:**
- `POST /api/auth/send-code` — phone entry
- `POST /api/auth/verify-code` — code verification + token receipt
- `POST /api/auth/complete` — username + display name + crypto key generation + encrypted profile upload (new users)
- `POST /api/auth/reset-identity` — fresh key generation + profile re-encryption for returning users on a new device
- `GET /api/auth/check-username` — live availability check on the username screen
- Session persistence: token in Keychain, username in UserDefaults
- Already-registered state detection and display
- New-device re-registration flow with user-facing explanation
- Feature flag wiring for `settings.more.experiments.userRegistration`
- Debug menu row for the new flag

**Out of scope:**
- Partner requests, sync, safety numbers
- Avatar upload (display name only for now)
- Production API URL switch
- Token refresh / expiry handling

---

## File Structure

```
Fuckify/
├── Core/
│   ├── Crypto/
│   │   ├── KeychainStore.swift           — Keychain read/write helper
│   │   ├── E2EEKeyManager.swift          — identity key generation + Keychain storage
│   │   ├── ProfileKeyManager.swift       — profile key storage + partner key cache
│   │   └── ProfileCrypto.swift           — AES-GCM profile encrypt/decrypt
│   └── Services/
│       ├── APIClient.swift               — URLSession HTTP client (registration endpoints)
│       └── RegistrationService.swift     — orchestrates send-code → verify-code → complete
├── Features/
│   ├── Experiments/
│   │   └── ExperimentsView.swift         — replaces inline ContentUnavailableView placeholder
│   └── Registration/
│       ├── RegistrationCoordinator.swift — @Observable state machine
│       ├── RegistrationContainerView.swift — NavigationStack driven by coordinator step
│       ├── PhoneEntryView.swift
│       ├── CodeVerifyView.swift
│       ├── UsernameView.swift
│       └── NewDeviceView.swift
```

**Existing files modified:**
- `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift` — add `ExperimentsFlags` struct, wire `experimentsFlags` on `SettingsMoreFlags`
- `Fuckify/Features/Settings/Debug/DebugMenuView.swift` — add `settings.more.experiments` sub-section with `userRegistration` row
- `Fuckify/Features/Settings/Views/SettingsView.swift` — replace inline `ContentUnavailableView` destination with `ExperimentsView()`

**Constraints:**
- `Core/Crypto/` files have zero SwiftUI imports — pure Foundation + CryptoKit
- `Core/Services/` files have zero SwiftUI imports — pure Foundation
- All `Core/Crypto/` implementations match `docs/api/frontend.md` exactly

---

## Section 1: Core Crypto (`Core/Crypto/`)

Four files, copied verbatim from `docs/api/frontend.md`. No modifications.

| File | Source in frontend.md |
|------|----------------------|
| `KeychainStore.swift` | `Crypto/KeychainStore.swift` section |
| `E2EEKeyManager.swift` | `Crypto/E2EEKeyManager.swift` section |
| `ProfileKeyManager.swift` | `Crypto/ProfileKeyManager.swift` section |
| `ProfileCrypto.swift` | `Crypto/ProfileCrypto.swift` section |

**Keychain service identifiers** (as in frontend.md):
- Identity keys: `"com.myapp.e2ee.identity"`
- Profile key: `"com.myapp.profile"`

These will be updated to use the app's bundle ID (`baby.safi.Fuckify`) in a future hardening pass. For now, use the frontend.md values to keep the implementation identical to the spec.

---

## Section 2: API Client (`Core/Services/APIClient.swift`)

`final class APIClient` with:
- `var baseURL = URL(string: "https://dev.coitalcomra.de")!`
- `var authToken: String?`
- Generic `post<T>` and `get<T>` helpers using `URLSession.shared`
- Registration endpoints only for now:
  - `sendCode(phone:)` — `POST /api/auth/send-code`
  - `verifyCode(phone:code:)` → `VerifyResp` — `POST /api/auth/verify-code`
  - `checkUsername(_:)` → `Bool` — `GET /api/auth/check-username?username=`
  - `completeRegistration(body:)` — `POST /api/auth/complete`
  - `resetIdentity(body:)` — `POST /api/auth/reset-identity`

**Error model:** on non-2xx, decode PocketBase error shape `{ status, message, data }` and throw a typed `APIError.server(status: Int, message: String)`. Fall back to `APIError.network(URLError)` on transport failures.

```swift
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
```

All views display `error.localizedDescription` — no raw status codes shown to the user.

Implementation matches `docs/api/frontend.md` `Services/APIClient.swift` section, with `baseURL` updated to dev and `APIError` added.

---

## Section 3: Registration Service (`Core/Services/RegistrationService.swift`)

`final class RegistrationService` (not `@Observable`):

```swift
final class RegistrationService {
    private let api = APIClient.shared
    private let km  = E2EEKeyManager.shared

    func sendCode(phone: String) async throws
    func verifyCode(phone: String, code: String) async throws -> VerifyResp
    func completeRegistration(username: String, displayName: String) async throws
    func resetIdentity(displayName: String) async throws
}
```

`completeRegistration` does exactly:
1. `E2EEKeyManager.shared.installAndBuildRegistrationBundle(opkCount: 100)`
2. `ProfileKeyManager.shared.profileKey()` — generates and stores profile key if not present
3. `ProfileCrypto.encrypt(PlaintextProfile(displayName:), key:)` — returns `(blob: String, nonce: String)` but only `blob` is used; the nonce is embedded in the AES-GCM combined output per the API spec (no separate `nonce` field in `POST /api/auth/complete`)
4. `POST /api/auth/complete` with full body per API spec — `encrypted_blob` only, no `nonce` field
5. Writes `username` to `UserDefaults.standard` under key `"cc.username"`
6. Does NOT store the token — the coordinator handles that after `verifyCode`

`resetIdentity` does exactly:
1. `E2EEKeyManager.shared.installAndBuildRegistrationBundle(opkCount: 100)` — generates a completely fresh key bundle, overwriting any existing Keychain keys
2. `ProfileKeyManager.shared.profileKey()` — generates a new profile key (old one is gone since Keychain doesn't transfer between devices)
3. `ProfileCrypto.encrypt(PlaintextProfile(displayName:), key:)` — re-encrypts profile with new profile key
4. `POST /api/auth/reset-identity` — same body shape as `complete` minus `username`
5. Does NOT write to `UserDefaults` — username is preserved on the server and was already read from Keychain/UserDefaults by the coordinator during `verifyCode`

**Token storage:** `RegistrationService.verifyCode` returns `VerifyResp`. The coordinator writes `resp.token` to Keychain (service `"baby.safi.Fuckify.auth"`, account `"bearerToken"`) and sets `APIClient.shared.authToken = resp.token`.

---

## Section 4: Registration Coordinator (`Features/Registration/RegistrationCoordinator.swift`)

```swift
enum RegistrationStep: Equatable {
    case phone
    case code(phone: String)
    case username(phone: String, token: String, userID: String)  // new user
    case newDevice(token: String, username: String)               // returning user, no local keys
    case registered(username: String)
}

@Observable
@MainActor
final class RegistrationCoordinator {
    private(set) var step: RegistrationStep
    private(set) var isLoading = false
    var errorMessage: String? = nil

    private let service = RegistrationService()
    private let tokenStore = KeychainStore(service: "baby.safi.Fuckify.auth")

    init() {
        // Detect existing session on this device
        if let username = UserDefaults.standard.string(forKey: "cc.username") {
            step = .registered(username: username)
        } else {
            step = .phone
        }
    }

    func sendCode(phone: String) async
    func verifyCode(phone: String, code: String) async
    func completeRegistration(username: String, displayName: String) async
    func resetIdentity(displayName: String) async
}
```

**Step transitions:**
- `sendCode` → `.code(phone:)` on success
- `verifyCode`:
  - `isNewUser == true` → `.username(phone:token:userID:)`
  - `isNewUser == false`:
    - Check `E2EEKeyManager` for existing identity signing key in Keychain
    - Keys present → `.registered(username:)` (username read from UserDefaults; if somehow nil, set `errorMessage` and stay on `.phone`)
    - Keys absent (new device) → `.newDevice(token:username:)`. Username comes from UserDefaults `"cc.username"` if present; if also absent (truly fresh install with an existing server account and no prior app data), set `errorMessage = "Account found but username not stored on this device."` and stay on `.phone` — this edge case is not handled in this experiment.
- `completeRegistration` → `.registered(username:)`
- `resetIdentity` → `.registered(username:)` (username was already in the `.newDevice` step payload)

**Token write** happens inside `verifyCode` in the coordinator, immediately after receiving `VerifyResp`:
```swift
try? tokenStore.set(Data(resp.token.utf8), account: "bearerToken")
APIClient.shared.authToken = resp.token
```

**Error handling:** all `catch` blocks set `errorMessage = error.localizedDescription`. `isLoading` is always reset in a `defer` block.

---

## Section 5: UI (`Features/Registration/`)

### `RegistrationContainerView`

Owns `@State private var coordinator = RegistrationCoordinator()`. Passes it via `@Environment`. Contains a `NavigationStack` that switches on `coordinator.step`:

```swift
switch coordinator.step {
case .phone:                         PhoneEntryView()
case .code(let phone):               CodeVerifyView(phone: phone)
case .username(_, _, _):             UsernameView()
case .newDevice(_, let username):    NewDeviceView(username: username)
case .registered(let u):             RegisteredView(username: u)
}
```

`RegisteredView` is a simple inline view (not a separate file): `ContentUnavailableView`-style layout showing "Registered as @\(username)" with a `person.crop.circle.fill` SF symbol.

### `PhoneEntryView`

- `@Environment(RegistrationCoordinator.self)` for actions + loading state
- `@State private var phone = ""`
- `TextField` with `.keyboardType(.phonePad)`
- E.164 formatting: prefix `+` if not present, strip non-digits otherwise — applied in `.onChange`
- "Send Code" `Button` → `await coordinator.sendCode(phone: phone)`
- Disabled + `ProgressView` while `coordinator.isLoading`
- `.alert` bound to `$coordinator.errorMessage`

### `CodeVerifyView`

- Receives `phone: String` from the step enum (passed as init param)
- `@State private var code = ""`
- `TextField` limited to 6 digits, `.keyboardType(.numberPad)`
- "Verify" `Button` → `await coordinator.verifyCode(phone: phone, code: code)`
- "Resend code" `Button` → `await coordinator.sendCode(phone: phone)` (same phone)
- Disabled + spinner while loading, alert on error

### `NewDeviceView`

Shown when `isNewUser == false` but no local Keychain keys exist. Explains the situation to the user before performing the reset.

- Receives `username: String` from the step enum (init param)
- Non-scrolling layout with:
  - Heading: "Welcome back, @\(username)"
  - Body text: "Your account was found on the server, but your encryption keys aren't on this device. This happens when you get a new phone — your keys never leave your device and can't be transferred. Tap below to generate new keys and re-link your account. Your username is preserved. Your partners will need to re-sync with you after this."
  - `@State private var displayName = ""` text field — required to re-encrypt the profile blob
  - "Set Up New Device" primary button → `await coordinator.resetIdentity(displayName: displayName)`, disabled while loading or displayName is empty
- Spinner while `coordinator.isLoading`
- Alert on `coordinator.errorMessage`

### `UsernameView`

- `@Environment(RegistrationCoordinator.self)` for `completeRegistration` + loading
- `@State private var username = ""`
- `@State private var displayName = ""`
- `@State private var usernameAvailable: Bool? = nil` — `nil` = unchecked, `true` = available, `false` = taken/invalid
- Live availability check: `.onChange(of: username)` debounced 500ms via `Task.sleep`, calls `APIClient.shared.checkUsername(username)`
- Username field trailing icon: `checkmark.circle.fill` (green) when `true`, `xmark.circle.fill` (red) when `false`, `ProgressView` while checking
- "Finish" button → `await coordinator.completeRegistration(username:displayName:)`, disabled unless `usernameAvailable == true && !displayName.isEmpty && !coordinator.isLoading`
- Alert on error

---

## Section 6: Experiments Entry Point

### `ExperimentsView` (`Features/Experiments/ExperimentsView.swift`)

Replaces the inline `ContentUnavailableView` in `SettingsView`. A `Form` with one section:

```swift
struct ExperimentsView: View {
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var registeredUsername: String? = UserDefaults.standard.string(forKey: "cc.username")

    var body: some View {
        Form {
            if featureFlags.settings.more.experimentsFlags.userRegistration {
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
        }
        .navigationTitle("Experiments")
    }
}
```

`SettingsView` is updated: the `ContentUnavailableView` inline destination becomes `ExperimentsView()`.

---

## Section 7: Feature Flag Wiring

### `FeatureFlagsProvider.swift` changes

**Add `ExperimentsFlags` struct:**
```swift
@MainActor
struct ExperimentsFlags {
    let provider: FeatureFlagsProvider
    var userRegistration: Bool { provider.isEnabled(.settingsMoreExperimentsUserRegistration) }
}
```

**Add `experimentsFlags` to `SettingsMoreFlags`:**
```swift
var experimentsFlags: ExperimentsFlags { ExperimentsFlags(provider: provider) }
```

### `DebugMenuView.swift` changes

Add a new sub-section under `settings.more`:

```
Section("settings.more.experiments") {
    flagRow("userRegistration",
            key: "settings.more.experiments.userRegistration",
            current: featureFlags.settings.more.experimentsFlags.userRegistration)
}
```

---

## Section 8: URL Updates

### `FeatureFlagsService.swift`

Change:
```swift
private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"
```
To:
```swift
private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"
```

---

## Error Handling Summary

| Error source | User-visible message | Recovery |
|---|---|---|
| Invalid phone format | Server returns 400, `APIError.server` message shown | Fix phone number, retry |
| Bad/expired SMS code | Server 400, message shown | Re-enter or resend |
| Username taken | Server 400, shown in alert | Choose different username |
| Username already registered | Server 400 "already registered" | Coordinator checks UserDefaults first, so this should not occur in practice |
| New device, username not in UserDefaults | `errorMessage` set, stays on `.phone` | Edge case; out of scope for this experiment |
| `reset-identity` SPK signature invalid | Server 400, shown in alert | Retry (fresh key generation on retry) |
| Network failure | `URLError` localised description | Retry button (same action) |
| Keychain write failure | Silent — registration still succeeds; token just not persisted across launches | Next launch will prompt registration again |

---

## What Is Not Built

- Token restore on app launch (checking Keychain for existing token on startup)
- Token expiry / refresh
- Avatar upload
- Production URL switch
- Logout / deregister
- `ITSAppUsesNonExemptEncryption = NO` in `Info.plist` (needs to be added before App Store submission)
