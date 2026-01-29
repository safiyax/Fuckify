//
//  LockScreenView.swift
//  Fuckify
//
//  Lock screen that appears when app is launched with security enabled
//

import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var settings = SecuritySettings.shared
    @State private var pin = ""
    @State private var showError = false
    @State private var attempts = 0
    @State private var unlockAnimation = false
    @State private var isAuthenticating = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Background with blur when inactive (for app switcher privacy)
            Color.black.ignoresSafeArea()
            
            if scenePhase == .inactive {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .blur(radius: 20)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon/Logo
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Coital Comrade")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // PIN Entry
                if settings.isPINEnabled {
                    VStack(spacing: 24) {
                        Text("Enter PIN")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // PIN Dots
                        HStack(spacing: 20) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(pin.count > index ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if showError {
                            Text("Incorrect PIN")
                                .font(.caption)
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    
                    // Number Pad
                    VStack(spacing: 16) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 16) {
                                ForEach(1..<4) { col in
                                    let number = row * 3 + col
                                    LockScreenNumberButton(number: "\(number)") {
                                        addDigit("\(number)")
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 16) {
                            // Biometric button (if available)
                            if settings.isBiometricEnabled {
                                Button {
                                    authenticateWithBiometrics()
                                } label: {
                                    Image(systemName: settings.biometricType == .faceID ? "faceid" : "touchid")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 70, height: 70)
                                }
                            } else {
                                Color.clear
                                    .frame(width: 70, height: 70)
                            }
                            
                            LockScreenNumberButton(number: "0") {
                                addDigit("0")
                            }
                            
                            Button {
                                deleteDigit()
                            } label: {
                                Image(systemName: "delete.left.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 70, height: 70)
                            }
                        }
                    }
                } else if settings.isBiometricEnabled {
                    // Only biometric, no PIN
                    Button {
                        authenticateWithBiometrics()
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: settings.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Unlock with \(settings.biometricDisplayName)")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(40)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .scaleEffect(unlockAnimation ? 1.5 : 1.0)
        .opacity(unlockAnimation ? 0 : 1)
        .onAppear {
            // Auto-trigger biometric if enabled when lock screen first appears
            if settings.isBiometricEnabled && !isAuthenticating {
                // Small delay to let the view settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authenticateWithBiometrics()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Re-trigger biometric when app becomes active from any non-active state
            // This includes app switcher (.inactive → .active) and backgrounding (.background → .active)
            if oldPhase != .active && newPhase == .active && settings.isBiometricEnabled && !isAuthenticating {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometrics()
                }
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        guard pin.count < 4 else { return }
        pin += digit
        showError = false
        
        if pin.count == 4 {
            // Verify PIN
            if settings.verifyPIN(pin) {
                unlockWithAnimation()
            } else {
                // Wrong PIN
                attempts += 1
                withAnimation {
                    showError = true
                }
                
                // Reset PIN after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    pin = ""
                }
            }
        }
    }
    
    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
            showError = false
        }
    }
    
    private func authenticateWithBiometrics() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        Task {
            let success = await settings.authenticateWithBiometrics()
            await MainActor.run {
                isAuthenticating = false
                if success {
                    unlockWithAnimation()
                }
            }
        }
    }
    
    private func unlockWithAnimation() {
        withAnimation(.easeInOut(duration: 0.4)) {
            unlockAnimation = true
        }
        
        // Delay actual unlock to let animation complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isUnlocked = true
        }
    }
}

// MARK: - Lock Screen Number Button

struct LockScreenNumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(Color.white.opacity(0.1))
                .cornerRadius(35)
        }
    }
}

#Preview {
    LockScreenView(isUnlocked: .constant(false))
}
