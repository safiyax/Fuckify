//
//  DebugMenuFlagDetailView.swift
//  Fuckify
//
//  Detail view for CCDebugMenu feature flag
//

import SwiftUI

struct DebugMenuFlagDetailView: View {
    @State private var flagsManager = FeatureFlagsManager.shared
    
    var body: some View {
        Form {
            Section {
                Text("Controls whether the Debug Menu is visible in Settings. When enabled, all feature flags are checked on every app launch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Flag Status") {
                DebugFlagRow(label: "Debug Menu Enabled", value: $flagsManager.isDebugMenuEnabled)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavior when enabled:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• All feature flags reload on every app launch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Debug Menu appears in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Version cache is bypassed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("CCDebugMenu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DebugMenuFlagDetailView()
    }
}
