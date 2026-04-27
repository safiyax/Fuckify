# Coital Comrade — Backend API Reference

**Base URL (prod):** `https://api.coitalcomrade.safiya.sh`
**Base URL (dev):** `https://api.dev.coitalcomrade.safiya.sh`

All request and response bodies are JSON. All authenticated endpoints require an `Authorization: Bearer <token>` header. Tokens are obtained from `POST /api/auth/verify-code`.

---

## Authentication overview

The app uses phone-number authentication via Twilio Verify SMS. There is no password. The flow is:

1. `POST /api/auth/send-code` — send an SMS code to a phone number
2. `POST /api/auth/verify-code` — verify the code, receive a bearer token
3. `POST /api/auth/complete` *(new users only)* — set username, upload crypto keys, upload encrypted profile

The bearer token is a standard PocketBase JWT. Store it in the Keychain and include it on every authenticated request. Tokens do not currently expire on a short cycle — treat them as long-lived session tokens.

---

## Error responses

All errors follow PocketBase's standard shape:

```json
{
  "status": 400,
  "message": "username must be 3–32 characters",
  "data": {}
}
```

`data` may contain field-level validation details on 400 errors. Common status codes:

| Code | Meaning |
|------|---------|
| 400 | Bad request / validation failure |
| 401 | Missing or invalid auth token |
| 403 | Forbidden (correct token, wrong permissions) |
| 404 | Resource not found |
| 500 | Server error |

---

## Registration

### `POST /api/auth/send-code`

**Public.** Sends a 6-digit SMS verification code to the given phone number via Twilio Verify. The phone number is never stored on the server.

**Request**
```json
{ "phone": "+14155552671" }
```

`phone` must be E.164 format (starts with `+`, minimum 8 characters).

**Response `200`**
```json
{ "sent": true }
```

**Errors**
- `400` — phone not E.164 format
- `500` — Twilio error (invalid credentials, unreachable, etc.)

---

### `POST /api/auth/verify-code`

**Public.** Verifies the SMS code. For new users, creates an account. Returns a bearer token regardless.

**Request**
```json
{
  "phone": "+14155552671",
  "code": "123456"
}
```

**Response `200`**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user_id": "abc123def456ghi",
  "is_new_user": true
}
```

`is_new_user: true` means the app must call `POST /api/auth/complete` before the user can do anything else. `is_new_user: false` means the user has a fully registered account.

**Errors**
- `400` — invalid or expired code, or phone not E.164 format
- `500` — account creation failed

---

### `GET /api/auth/check-username?username=alice`

**Public.** Check whether a username is available before committing to it. Does **not** consume a one-time prekey (unlike `GET /api/e2ee/users/:username/keys`).

**Response `200`**
```json
{ "available": true }
```

Returns `available: false` for usernames that are taken, too short (< 3), too long (> 32), or contain invalid characters. Valid characters: letters, numbers, `_`, `-`.

---

### `POST /api/auth/complete`

**Authenticated.** Called exactly once for new users, after `verify-code` returns `is_new_user: true`. Sets the username, uploads the user's cryptographic identity, and stores the encrypted profile blob. All three are written atomically — if any part fails, nothing is saved.

**Request**
```json
{
  "username": "alice",
  "encrypted_blob": "<base64 AES-GCM sealed profile>",
  "identity_signing_pub": "<base64 Ed25519 public key, 44 chars>",
  "identity_agreement_pub": "<base64 X25519 public key, 44 chars>",
  "signed_prekey_id": 1,
  "signed_prekey_pub": "<base64 X25519 signed prekey, 44 chars>",
  "signed_prekey_sig": "<base64 Ed25519 signature over signed_prekey_pub, 88 chars>",
  "one_time_prekeys": [
    { "prekey_id": 1, "public_key": "<base64 X25519, 44 chars>" },
    { "prekey_id": 2, "public_key": "<base64 X25519, 44 chars>" }
  ]
}
```

**Key encoding:** all keys and signatures are **standard base64 with padding** (`=`), not base64url. Lengths are exact:
- Ed25519 public key: 32 bytes → 44 base64 chars
- X25519 public key: 32 bytes → 44 base64 chars
- Ed25519 signature: 64 bytes → 88 base64 chars

**`encrypted_blob`:** AES-GCM sealed profile data (see [Profile encryption](#profile-encryption)). Max 512 KB.

**`one_time_prekeys`:** 0–100 OPKs. Recommended to upload 100 on first registration. The server will reject > 100.

The server verifies that `signed_prekey_sig` is a valid Ed25519 signature of `signed_prekey_pub` under `identity_signing_pub`. If the signature is invalid the request is rejected with 400.

**Response `201`**
```json
{ "ok": true }
```

**Errors**
- `400` — username taken, invalid length/charset, invalid SPK signature, > 100 OPKs
- `400` — already registered (idempotent guard)

---

## Profile

### `GET /api/e2ee/profile/:username`

**Authenticated.** Fetch another user's encrypted profile blob. The client decrypts it locally using the profile key, which is shared via the sync channel (never sent to the server).

**Response `200`**
```json
{
  "username": "alice",
  "encrypted_blob": "<base64 AES-GCM sealed blob>",
  "version": 3
}
```

`version` is a monotonically increasing integer. Cache locally and re-fetch when the version you have is stale.

**Errors**
- `404` — user or profile not found

---

### `PUT /api/e2ee/profile`

**Authenticated.** Update your own encrypted profile (e.g. after changing display name or avatar). Increments `version` by 1.

**Request**
```json
{ "encrypted_blob": "<base64 AES-GCM sealed blob>" }
```

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `400` — missing `encrypted_blob`
- `404` — profile not found (call `/api/auth/complete` first)

---

### Profile encryption

The profile blob contains `{ displayName: String, avatarJpeg?: Data }` encrypted with AES-GCM using a 256-bit profile key that lives only in the iOS Keychain.

Use `AES.GCM.seal(plaintext, using: profileKey)` — this produces a **combined** output (`nonce || ciphertext || tag`) that you base64-encode and send as `encrypted_blob`. There is no separate nonce field. On decrypt, use `AES.GCM.SealedBox(combined: data)` which extracts the nonce automatically.

The profile key is shared between partners through the Double Ratchet sync channel, never directly via the server.

Max blob size after base64 encoding: 512 KB (covers a display name + ~200 KB compressed JPEG avatar).

---

## Key bundle

These endpoints manage the cryptographic keys used for X3DH key exchange.

### `GET /api/e2ee/users/:username/keys`

**Authenticated.** Fetch a user's public key bundle. **Atomically consumes one one-time prekey (OPK)** from their pool. Use this endpoint only when initiating a first sync with a new partner — not for general identity lookup (use `check-username` or `get-profile` for that).

**Response `200`**
```json
{
  "username": "alice",
  "identity_signing_pub": "<base64 Ed25519 pub>",
  "identity_agreement_pub": "<base64 X25519 pub>",
  "signed_prekey_id": 1,
  "signed_prekey_pub": "<base64 X25519 pub>",
  "signed_prekey_sig": "<base64 Ed25519 sig>",
  "one_time_prekey": {
    "prekey_id": 7,
    "public_key": "<base64 X25519 pub>"
  }
}
```

`one_time_prekey` is `null` when the pool is exhausted. This is valid per the X3DH spec — the client must handle it (slightly reduced forward secrecy for that session).

**Errors**
- `404` — user not found

---

### `POST /api/e2ee/users/:username/prekeys`

**Authenticated. Own account only.** Upload new one-time prekeys to replenish the pool. Check the pool count first with `GET .../prekeys/count` and top up when it falls below a threshold (e.g. < 10).

**Request**
```json
{
  "one_time_prekeys": [
    { "prekey_id": 101, "public_key": "<base64 X25519 pub>" },
    { "prekey_id": 102, "public_key": "<base64 X25519 pub>" }
  ]
}
```

1–100 OPKs per call. `prekey_id` must be unique per user — use a monotonically increasing counter stored in the Keychain.

**Response `200`**
```json
{ "added": 2 }
```

**Errors**
- `400` — 0 or > 100 items
- `403` — not your account

---

### `GET /api/e2ee/users/:username/prekeys/count`

**Authenticated. Own account only.** Returns how many OPKs remain in your pool.

**Response `200`**
```json
{ "count": 47 }
```

**Errors**
- `403` — not your account

---

### `PUT /api/e2ee/users/:username/signed-prekey`

**Authenticated. Own account only.** Rotate your signed prekey. The server re-verifies the new SPK signature against your stored identity signing key before accepting it. Rotate the SPK periodically (e.g. weekly).

**Request**
```json
{
  "signed_prekey_id": 2,
  "signed_prekey_pub": "<base64 X25519 pub>",
  "signed_prekey_sig": "<base64 Ed25519 sig over signed_prekey_pub>"
}
```

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `400` — invalid signature
- `403` — not your account

---

## Partners

Partners are the other users you sync encounter data with. The relationship is bidirectional and goes through a lifecycle: `pending` → `active` → `blocked`.

### `POST /api/e2ee/partners/request`

**Authenticated.** Send a partner request to another user by username.

**Request**
```json
{ "username": "bob" }
```

**Response `201`**
```json
{ "id": "partnerrecordid123" }
```

**Errors**
- `400` — relationship already exists (in any state), or trying to partner with yourself
- `404` — username not found, or your registration is incomplete

---

### `GET /api/e2ee/partners`

**Authenticated.** List all your partner relationships (all statuses). Returns up to 200 records, sorted by most recently updated.

**Response `200`**
```json
[
  {
    "id": "partnerrecordid123",
    "partner_username": "bob",
    "partner_id": "e2eeuserid456",
    "status": "active",
    "safety_numbers_verified": false,
    "is_requester": true
  }
]
```

`is_requester: true` means you sent the request. `is_requester: false` means they sent it to you (you are the recipient).

`status` values:
- `pending` — request sent, not yet accepted
- `active` — accepted, syncs allowed
- `blocked` — blocked by either party, syncs not allowed

---

### `PUT /api/e2ee/partners/:id/accept`

**Authenticated. Recipient only.** Accept a pending partner request.

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `400` — relationship is not in `pending` state
- `403` — you are not the recipient of this request
- `404` — partner record not found

---

### `PUT /api/e2ee/partners/:id/verified`

**Authenticated. Either party.** Mark safety numbers as verified after both users have compared the 60-digit fingerprint in person. This is purely informational — the server does not compute or verify safety numbers, it just records that you confirmed them.

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `400` — relationship is not `active`
- `403` — not your partner record

---

### `PUT /api/e2ee/partners/:id/block`

**Authenticated. Either party.** Block an active partner. Blocked partners cannot push sync payloads to each other. The block is one-way in the sense that either party can initiate it, but it prevents sync for both directions.

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `400` — relationship is not `active` (cannot block pending or already-blocked)
- `403` — not your partner record

---

## Sync

Encounter data is synced in two phases. The server stores encrypted blobs it cannot read. Sync requires an `active` partner relationship.

### Sync protocol overview

**Phase 1 — initiator pushes to partner:**
1. Initiator fetches partner's key bundle (`GET /api/e2ee/users/:username/keys`)
2. On first sync: performs X3DH key exchange using the bundle to derive a shared secret, seeds a Double Ratchet session
3. On subsequent syncs: advances the Double Ratchet session
4. Encrypts full encounter history as a JSON batch using the Double Ratchet session
5. POSTs the ciphertext to `POST /api/e2ee/sync/push` with `phase: 1`, `message_type: "x3dh_initial"` (first sync) or `"ratchet"` (subsequent)

**Phase 2 — partner responds:**
1. Partner polls `GET /api/e2ee/sync/incoming/:initiatorUsername` and finds the phase-1 payload
2. Partner decrypts it, merges encounters with their own local data
3. Partner encrypts their own encounter history and POSTs with `phase: 2`, `message_type: "ratchet"`
4. Partner deletes the phase-1 payload with `DELETE /api/e2ee/sync/payloads/:id`

**Initiator completes:**
1. Initiator polls `GET /api/e2ee/sync/incoming/:partnerUsername` and finds the phase-2 payload
2. Initiator decrypts it, performs final merge
3. Initiator deletes the phase-2 payload with `DELETE /api/e2ee/sync/payloads/:id`

**Conflict resolution (client-side only):** Two encounters are the same event if they share the same duration (±60 seconds), activity types, protection methods, and participant positions. On conflict, initiator's version wins. Encounters unique to either side are always kept.

---

### `POST /api/e2ee/sync/push`

**Authenticated.** Push an encrypted encounter batch to a partner. Replaces any existing payload for the same `(sender, recipient, phase)` triple — re-pushing phase 1 before the partner fetches it is safe.

**Request**
```json
{
  "recipient_username": "bob",
  "message_type": "x3dh_initial",
  "phase": 1,
  "payload": "<base64 encrypted batch, max 1 MB>"
}
```

`message_type`: `"x3dh_initial"` on the very first sync with a given partner, `"ratchet"` on all subsequent syncs.

`phase`: `1` (initiator → partner) or `2` (partner → initiator).

`payload`: base64-encoded ciphertext. Maximum 1 MB as a base64 string (~786 KB raw).

**Response `201`**
```json
{ "id": "syncpayloadid789" }
```

**Errors**
- `400` — invalid `message_type`, invalid `phase`, payload empty or > 1 MB
- `403` — no active partner relationship with recipient (pending or blocked)
- `404` — recipient username not found, or your registration is incomplete

---

### `GET /api/e2ee/sync/incoming/:partnerUsername`

**Authenticated.** Fetch pending sync payloads addressed to you from a specific partner. Returns up to 2 items (one per phase). The payload field contains the raw ciphertext to decrypt locally.

**Response `200`**
```json
[
  {
    "id": "syncpayloadid789",
    "message_type": "x3dh_initial",
    "phase": 1,
    "payload": "<base64 ciphertext>",
    "created": "2026-04-21 17:41:12.000Z"
  }
]
```

Returns an empty array `[]` if there are no pending payloads from this partner.

**Errors**
- `404` — partner username not found, or your registration is incomplete

---

### `DELETE /api/e2ee/sync/payloads/:id`

**Authenticated. Recipient only.** Delete a sync payload after you have successfully decrypted and processed it. Only the intended recipient (the user the payload was addressed to) can delete it.

**Response `200`**
```json
{ "ok": true }
```

**Errors**
- `403` — you are not the recipient of this payload
- `404` — payload not found

---

## Safety numbers

Safety numbers are a 60-digit fingerprint derived from both users' `identity_signing_pub` keys using Signal's iterated SHA-512 algorithm. They are computed **entirely on-device** — the server is not involved.

The intended UX is an in-person verification screen where both users compare the number. Once confirmed, call `PUT /api/e2ee/partners/:id/verified` to record it. This flag is informational only and does not affect encryption.

The fingerprint algorithm (matches Signal):
1. Sort the two Ed25519 public keys lexicographically
2. Concatenate: `version(5 bytes) || key1(32 bytes) || identifier1 || key2(32 bytes) || identifier2`
3. SHA-512 the result, then SHA-512 the output again, for 5200 total iterations
4. Chunk the final hash into 5-digit decimal groups

---

## What the server never sees

- Phone numbers (only SHA-256 hash, not reversible)
- Display names or avatars (AES-GCM encrypted, key never leaves device)
- Profile keys (exchanged only through the E2EE sync channel)
- Encounter data of any kind (opaque ciphertext blobs)
- Any private key material

The server knows: usernames, that two users are partners, partner status, when syncs happen, and approximate payload sizes.
