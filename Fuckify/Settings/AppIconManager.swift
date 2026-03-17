//
//  AppIconManager.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-09.
//

import SwiftUI

struct AppIconSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Choose your app icon to personalize your experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Available Icons") {
                AppIconPicker()
            }

            Section {
                Text("The app icon will change immediately after selection.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppIconPicker: View {
    @State private var selectedIcon: String?
    
    var body: some View {
        List {
            // Primary icon
            AppIconRow(
                iconName: nil,
                displayName: "Default",
                isSelected: selectedIcon == nil
            ) {
                AppIconManager.setIcon(named: nil) { error in
                    if error == nil {
                        selectedIcon = nil
                    }
                }
            }
            
            // Alternate icons
            ForEach(AppIconManager.availableIcons, id: \.self) { iconName in
                AppIconRow(
                    iconName: iconName,
                    displayName: iconName.capitalized,
                    isSelected: selectedIcon == iconName
                ) {
                    AppIconManager.setIcon(named: iconName) { error in
                        if error == nil {
                            selectedIcon = iconName
                        } else {
                            print(error.debugDescription)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedIcon = AppIconManager.currentIconName
        }
    }
}

struct AppIconRow: View {
    let iconName: String?
    let displayName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let iconNameImage = iconName {
                    Image("\(iconNameImage)-Image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Image("\(AppIconManager.primaryIconName)-Image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                }
                
                Text(displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// Enhanced AppIconManager
struct AppIconManager {
    static var availableIcons: [String] {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any] else {
            return []
        }
        return Array(alternateIcons.keys).sorted()
    }
    
    static var primaryIconName: String {
        // Get the primary icon name from the asset catalog compiler setting
        // Default is "CatIcon" as configured in the project
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return lastIcon
        }
        return "CatIcon"
    }
    
    static var currentIconName: String? {
        return UIApplication.shared.alternateIconName
    }
    
    static var isUsingPrimaryIcon: Bool {
        return UIApplication.shared.alternateIconName == nil
    }
    
    static func setIcon(named iconName: String?, completion: ((Error?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(NSError(domain: "AppIconManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Alternate icons not supported"]))
            return
        }
        
        UIApplication.shared.setAlternateIconName(iconName, completionHandler: completion)
    }
    
    // Get the icon image for display
    static func iconImage(for iconName: String?) -> UIImage? {
        // For primary icon
        guard let iconName = iconName else {
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last {
                print("Primary icon file name: \(lastIcon)")
                return UIImage(named: lastIcon)
            }
            return nil
        }
        
        // For alternate icons
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any],
              let iconDict = alternateIcons[iconName] as? [String: Any],
              let iconFiles = iconDict["CFBundleIconFiles"] as? [String] else {
            print("Could not find icon data for: \(iconName)")
            return UIImage(named: "\(iconName)-Image")
        }
        
        print("Icon files for \(iconName): \(iconFiles)")
        
        // Try each file name
        for fileName in iconFiles.reversed() {
            if let image = UIImage(named: fileName) {
                return image
            }
        }
        
        return nil
    }

    // Alternative: Get icon files array
    static func iconFiles(for iconName: String?) -> [String] {
        guard let iconName = iconName else {
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
                return iconFiles
            }
            return []
        }
        
        // iconName is now unwrapped
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any],
           let iconDict = alternateIcons[iconName] as? [String: Any],
           let iconFiles = iconDict["CFBundleIconFiles"] as? [String] {
            return iconFiles
        }
        return []
    }}

/*
#Preview {
    AppIconPicker()
}
*/
