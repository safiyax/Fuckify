//
//  AppIconManager.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-09.
//

import SwiftUI

struct AppIconSettingsView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    AppIconPicker()
                        .padding(.horizontal)
                        .padding(.top, 20)
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppIconPicker: View {
    @State private var selectedIcon: String?
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var allIcons: [(name: String?, displayName: String)] {
        var icons: [(String?, String)] = [(nil, "Default")]
        icons.append(contentsOf: AppIconManager.availableIcons.map { ($0, $0.capitalized) })
        return icons
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon Grid
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(allIcons, id: \.name) { icon in
                        AppIconGridItem(
                            iconName: icon.name,
                            isSelected: selectedIcon == icon.name
                        ) {
                            AppIconManager.setIcon(named: icon.name) { error in
                                if error == nil {
                                    selectedIcon = icon.name
                                } else {
                                    print(error.debugDescription)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            // Footer text
            VStack(alignment: .leading, spacing: 8) {
                Text("The app name \"Fuckify\" will be visible on the Home Screen, in notifications and in the App Library.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    // Open help link
                    if let url = URL(string: "https://support.apple.com/guide/iphone/change-the-app-icon-iph9c286cc31/ios") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Learn More")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .onAppear {
            selectedIcon = AppIconManager.currentIconName
        }
    }
}

struct AppIconGridItem: View {
    let iconName: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                if let iconNameImage = iconName {
                    Image("\(iconNameImage)-Image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .cornerRadius(16)
                } else {
                    Image("\(AppIconManager.primaryIconName)-Image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .cornerRadius(16)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(width: 20, height: 20)
                        )
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
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


#Preview {
    AppIconPicker()
}
