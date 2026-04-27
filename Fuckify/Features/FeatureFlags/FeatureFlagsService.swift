//
//  FeatureFlagsService.swift
//  Fuckify
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "FeatureFlags")

actor FeatureFlagsService {
    private let cacheKey = "feature_flags_cache"
    private let cacheTimestampKey = "feature_flags_cache_timestamp"
    private let baseURL = "https://api.dev.coitalcomrade.safiya.sh/api/feature-flags"

    // MARK: - Network

    func fetchFlags() async throws -> [String: FlagValue] {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "build", value: build),
            URLQueryItem(name: "platform", value: "ios")
        ]

        guard let url = components.url else {
            throw FeatureFlagsError.invalidURL
        }

        #if DEBUG
        // Bypass TLS validation in DEBUG so staging Let's Encrypt certs work.
        // Never runs in release builds.
        let session = URLSession(configuration: .default, delegate: TrustAllCertsDelegate(), delegateQueue: nil)
        let (data, response) = try await session.data(from: url)
        #else
        let (data, response) = try await URLSession.shared.data(from: url)
        #endif

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.warning("Feature flags API returned status \(code)")
            throw FeatureFlagsError.badResponse(code)
        }

        let flags = try JSONDecoder().decode([String: FlagValue].self, from: data)
        logger.info("Fetched \(flags.count) feature flags (version: \(version), build: \(build))")
        return flags
    }

    // MARK: - Cache

    func cachedFlags() -> [String: FlagValue] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let flags = try? JSONDecoder().decode([String: FlagValue].self, from: data) else {
            return [:]
        }
        return flags
    }

    func persistFlags(_ flags: [String: FlagValue]) {
        guard let data = try? JSONEncoder().encode(flags) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        logger.debug("Persisted \(flags.count) flags to cache")
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        logger.info("Feature flags cache cleared")
    }

    func lastFetchedDate() -> Date? {
        UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date
    }
}

// MARK: - Value type

struct FlagValue: Codable {
    let enabled: Bool
    let premium: Bool
}

// MARK: - Errors

enum FeatureFlagsError: Error {
    case badResponse(Int)
    case invalidURL
}

// MARK: - Debug TLS bypass

#if DEBUG
/// Bypasses TLS certificate validation in DEBUG builds only.
/// Used while the staging Let's Encrypt cert is active. Remove once prod cert is issued.
private final class TrustAllCertsDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
