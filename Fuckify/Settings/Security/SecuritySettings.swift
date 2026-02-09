//
//  SecuritySettings.swift
//  Fuckify
//
//  Manages app security settings (PIN and biometric authentication)
//

import Foundation
import LocalAuthentication
import CryptoKit

@MainActor
@Observable
class SecuritySettings {
    static let shared = SecuritySettings()
    
    // MARK: - Stored Properties
    
    var isPINEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "security_isPINEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "security_isPINEnabled")
        }
    }
    
    var isBiometricEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "security_isBiometricEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "security_isBiometricEnabled")
        }
    }
    
    private var storedPINHash: String? {
        get {
            UserDefaults.standard.string(forKey: "security_pinHash")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "security_pinHash")
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
    
    private init() {}
    
    // MARK: - PIN Management
    
    func setPIN(_ pin: String) {
        storedPINHash = hashPIN(pin)
        isPINEnabled = true
    }
    
    func verifyPIN(_ pin: String) -> Bool {
//        return true
        guard let storedHash = storedPINHash else { return false }
        return hashPIN(pin) == storedHash
    }
    
    func removePIN() {
        storedPINHash = nil
        isPINEnabled = false
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
            return success
        } catch {
            return false
        }
    }
    
    // MARK: - Reset
    
    func resetAllSecurity() {
        isPINEnabled = false
        isBiometricEnabled = false
        storedPINHash = nil
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case faceID
    case touchID
    case none
}
