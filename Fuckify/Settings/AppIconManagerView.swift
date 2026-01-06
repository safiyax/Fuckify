//
//  AppIconManagerView.swift
//  Fuckify
//
//

import SwiftUI

// MARK: - App Icon Model

enum AppIcon: String, CaseIterable, Identifiable {
    case defaultIcon = "Default"
    case dark = "Dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultIcon:
            return "Default"
        case .dark:
            return "Dark"
        }
    }

    var description: String {
        switch self {
        case .defaultIcon:
            return "The classic Fuckify icon"
        case .dark:
            return "Perfect for dark mode lovers"
        }
    }

    var iconName: String? {
        switch self {
        case .defaultIcon:
            return nil // Primary icon doesn't need a name
        case .dark:
            return rawValue
        }
    }
    
    var bundleValue: String? {
        switch self {
        case .defaultIcon: nil
        case .dark: "Dark"
        }
    }
}

// MARK: - App Icon Manager View

struct AppIconManagerView: View {
    @State private var showError = false
    @State private var errorMessage = ""
    
    @AppStorage("CurrentAppIcon") private var currentSelection: AppIcon = .defaultIcon

    var body: some View {
        Form {
            Section {
                Text("Choose your app icon to personalize your experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Available Icons") {
                Picker("", selection: $currentSelection) {
                    ForEach(AppIcon.allCases, id: \.rawValue) { icon in
                        Text(icon.rawValue)
                            .tag(icon)
                    }
                }
//                ForEach(AppIcon.allCases, id: \.rawValue) { icon in
//                    Button {
//                        Task {
//                            await changeIcon(to: icon)
//                        }
////                        currentSelection = icon
//                    } label: {
//                        HStack(spacing: 12) {
//                            // Icon preview - using actual icon from Icons directory
//                            Image(icon.displayName)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 60, height: 60)
//                                .clipShape(RoundedRectangle(cornerRadius: 14))
//                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
//
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text(icon.displayName)
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//
//                                Text(icon.description)
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                            }
//
//                            Spacer()
//
//                            if iconManager.currentIcon == icon {
//                                Image(systemName: "checkmark.circle.fill")
//                                    .foregroundColor(.green)
//                                    .font(.title3)
//                            }
//                        }
//                        .padding(.vertical, 8)
//                    }
//                    .buttonStyle(.plain)
//                }
            }

            Section {
                Text("The app icon will change immediately after selection.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: currentSelection, { oldValue, newValue in
            UIApplication.shared.setAlternateIconName(newValue.bundleValue)
        })
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func changeIcon(to icon: AppIcon) async {
        do {
//            try await iconManager.setIcon(icon)
            try await UIApplication.shared.setAlternateIconName(icon.bundleValue)

            // Haptic feedback on success
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Haptic feedback on error
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

#Preview {
    NavigationStack {
        AppIconManagerView()
    }
}
