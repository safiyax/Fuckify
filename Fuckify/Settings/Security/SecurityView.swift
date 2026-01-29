//
//  SecurityView.swift
//  Fuckify
//
//  View for managing app security settings
//

import SwiftUI
import LocalAuthentication

struct SecurityView: View {
    @State private var settings = SecuritySettings.shared
    @State private var showingPINSetup = false
    @State private var showingPINRemoval = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""
    @State private var refreshTrigger = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Add an extra layer of protection to your intimate data with a PIN or biometric authentication.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // PIN Section
                Section("PIN Code") {
                    if settings.isPINEnabled {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.green)
                            Text("PIN Enabled")
                            Spacer()
                            Button("Change") {
                                showingPINSetup = true
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Button(role: .destructive) {
                            showingPINRemoval = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.slash.fill")
                                Text("Remove PIN")
                            }
                        }
                    } else {
                        Button {
                            showingPINSetup = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.blue)
                                Text("Set Up PIN")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Biometric Section
                #if DEBUG
                Section("Debug") {
                    Text("Biometric Type: \(String(describing: settings.biometricType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
                
                if settings.biometricType != .none {
                    Section(settings.biometricDisplayName) {
                        Toggle(isOn: $settings.isBiometricEnabled) {
                            HStack {
                                Image(systemName: settings.biometricType == .faceID ? "faceid" : "touchid")
                                    .foregroundColor(.blue)
                                Text("Enable \(settings.biometricDisplayName)")
                            }
                        }
                        .onChange(of: settings.isBiometricEnabled) { _, newValue in
                            if newValue {
                                // Test biometric authentication when enabled
                                Task {
                                    let success = await settings.authenticateWithBiometrics()
                                    if !success {
                                        settings.isBiometricEnabled = false
                                        biometricErrorMessage = "Failed to authenticate with \(settings.biometricDisplayName)"
                                        showingBiometricError = true
                                    }
                                }
                            }
                        }
                        
                        if settings.isBiometricEnabled {
                            Text("You'll be prompted to use \(settings.biometricDisplayName) when opening the app.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Info Section
                if settings.isSecurityEnabled {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Security is active. You'll need to authenticate when opening the app.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPINSetup) {
                PINSetupView()
            }
            .onChange(of: showingPINSetup) { _, isShowing in
                if !isShowing {
                    // Refresh view when PIN setup is dismissed
                    refreshTrigger.toggle()
                }
            }
            .sheet(isPresented: $showingPINRemoval) {
                PINRemovalView()
            }
            .onChange(of: showingPINRemoval) { _, isShowing in
                if !isShowing {
                    // Refresh view when PIN removal is dismissed
                    refreshTrigger.toggle()
                }
            }
            .id(refreshTrigger)
            .alert("Authentication Failed", isPresented: $showingBiometricError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(biometricErrorMessage)
            }
        }
    }
}

// MARK: - PIN Setup View

struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: SetupStep = .enter
    @State private var errorMessage = ""
    @State private var showError = false
    
    enum SetupStep {
        case enter, confirm
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(step == .enter ? "Create PIN" : "Confirm PIN")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(step == .enter ? "Enter a 4-digit PIN" : "Enter your PIN again")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // PIN Display
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(getCurrentPIN().count > index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical)
                
                // Number Pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 16) {
                            ForEach(1..<4) { col in
                                let number = row * 3 + col
                                NumberButton(number: "\(number)") {
                                    addDigit("\(number)")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Color.clear
                            .frame(width: 80, height: 80)
                        
                        NumberButton(number: "0") {
                            addDigit("0")
                        }
                        
                        Button {
                            deleteDigit()
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(40)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Set Up PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    // Reset to first step
                    step = .enter
                    pin = ""
                    confirmPin = ""
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func getCurrentPIN() -> String {
        step == .enter ? pin : confirmPin
    }
    
    private func addDigit(_ digit: String) {
        if step == .enter {
            guard pin.count < 4 else { return }
            pin += digit
            
            if pin.count == 4 {
                // Move to confirmation step
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    step = .confirm
                }
            }
        } else {
            guard confirmPin.count < 4 else { return }
            confirmPin += digit
            
            if confirmPin.count == 4 {
                // Verify PINs match
                if pin == confirmPin {
                    SecuritySettings.shared.setPIN(pin)
                    dismiss()
                } else {
                    errorMessage = "PINs don't match. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func deleteDigit() {
        if step == .enter {
            if !pin.isEmpty {
                pin.removeLast()
            }
        } else {
            if !confirmPin.isEmpty {
                confirmPin.removeLast()
            } else {
                // Go back to enter step
                step = .enter
                pin = ""
            }
        }
    }
}

// MARK: - PIN Removal View

struct PINRemovalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.slash.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    Text("Remove PIN")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your current PIN to remove it")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // PIN Display
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(pin.count > index ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical)
                
                // Number Pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 16) {
                            ForEach(1..<4) { col in
                                let number = row * 3 + col
                                NumberButton(number: "\(number)") {
                                    addDigit("\(number)")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Color.clear
                            .frame(width: 80, height: 80)
                        
                        NumberButton(number: "0") {
                            addDigit("0")
                        }
                        
                        Button {
                            deleteDigit()
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(40)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Remove PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    pin = ""
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        guard pin.count < 4 else { return }
        pin += digit
        
        if pin.count == 4 {
            // Verify PIN
            if SecuritySettings.shared.verifyPIN(pin) {
                SecuritySettings.shared.removePIN()
                dismiss()
            } else {
                errorMessage = "Incorrect PIN. Please try again."
                showError = true
            }
        }
    }
    
    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
        }
    }
}

// MARK: - Number Button Component

struct NumberButton: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(40)
        }
    }
}

#Preview {
    SecurityView()
}
