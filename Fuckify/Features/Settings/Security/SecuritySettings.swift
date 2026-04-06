//
//  SecuritySettings.swift
//  Fuckify
//
//  Manages app security settings (PIN and biometric authentication)
//  Uses stored properties with didSet observers for proper SwiftUI observation
//

import Foundation
import LocalAuthentication
import CryptoKit

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "Security")

/// Security settings for app lock functionality
/// 
/// Supports both PIN and biometric authentication (Face ID/Touch ID).
/// Uses stored properties instead of computed properties to ensure
/// SwiftUI's @Observable system properly tracks changes.
@MainActor
@Observable
final class SecuritySettings {
    // MARK: - Stored Properties
    
    /// Whether PIN authentication is enabled
    var isPINEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPINEnabled, forKey: "security_isPINEnabled")
        }
    }
    
    /// Whether biometric authentication (Face ID/Touch ID) is enabled
    var isBiometricEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBiometricEnabled, forKey: "security_isBiometricEnabled")
        }
    }
    
    /// Hashed PIN for verification (SHA256)
    private var storedPINHash: String? {
        didSet {
            if let hash = storedPINHash {
                UserDefaults.standard.set(hash, forKey: "security_pinHash")
            } else {
                UserDefaults.standard.removeObject(forKey: "security_pinHash")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var isSecurityEnabled: Bool {
        isPINEnabled || isBiometricEnabled
    }
    
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Biometric"
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize security settings, loading values from UserDefaults
    init() {
        // Load values from UserDefaults
        self.isPINEnabled = UserDefaults.standard.bool(forKey: "security_isPINEnabled")
        self.isBiometricEnabled = UserDefaults.standard.bool(forKey: "security_isBiometricEnabled")
        self.storedPINHash = UserDefaults.standard.string(forKey: "security_pinHash")
    }
    
    // MARK: - PIN Management
    
    func setPIN(_ pin: String) {
        storedPINHash = hashPIN(pin)
        isPINEnabled = true
        logger.info("PIN authentication enabled")
    }
    
    func verifyPIN(_ pin: String) -> Bool {
//        return true
        guard let storedHash = storedPINHash else { return false }
        return hashPIN(pin) == storedHash
    }
    
    func removePIN() {
        storedPINHash = nil
        isPINEnabled = false
        logger.info("PIN authentication removed")
    }
    
    private func hashPIN(_ pin: String) -> String {
        // Use SHA256 for consistent hashing
        let inputData = Data(pin.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            let reason = "Unlock Coital Comrade"
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            logger.info("Biometric authentication \(success ? "succeeded" : "failed")")
            return success
        } catch {
            logger.error("Biometric authentication error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Reset
    
    func resetAllSecurity() {
        isPINEnabled = false
        isBiometricEnabled = false
        storedPINHash = nil
        logger.info("All security settings reset")
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case faceID
    case touchID
    case none
}
