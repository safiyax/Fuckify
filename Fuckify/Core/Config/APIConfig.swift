//
//  APIConfig.swift
//  Fuckify
//

import Foundation

/// Single source of truth for all backend API configuration.
///
/// Use `.debug` for simulator / TestFlight builds against the staging server.
/// Use `.release` for App Store builds against the production server.
enum APIConfig {
    enum Environment {
        case debug
        case release
    }

    static var environment: Environment {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    /// Base URL for the API.
    static var baseURL: String {
        switch environment {
        case .debug:  return "https://dev.coitalcomra.de"
        case .release: return "https://coitalcomra.de"
        }
    }
}
