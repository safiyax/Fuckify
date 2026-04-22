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

    var baseURL = URL(string: "https://api.dev.coitalcomrade.safiya.sh")!
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
