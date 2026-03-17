//
//  AcknowledgementsView.swift
//  Fuckify
//
//  SwiftUI wrapper for AknowList acknowledgements
//

import SwiftUI
import AcknowList

struct AcknowledgementsView: View {
    var body: some View {
        Group {
            if let acknowList = loadAcknowledgements() {
                // Show acknowledgements if Package.resolved was found and parsed
                AcknowListSwiftUIView(acknowList: acknowList)
            } else {
                // Fallback if no Package.resolved found
                ContentUnavailableView(
                    "No Acknowledgements Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Could not load package acknowledgements.\nMake sure Package.resolved is added to the app bundle.")
                )
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadAcknowledgements() -> AcknowList? {
        // First try to load from the app bundle (production)
        if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
           let data = try? Data(contentsOf: url),
           let acknowList = try? AcknowPackageDecoder().decode(from: data) {
            return acknowList
        }
        
        // Fallback: Try to load from workspace (development)
        #if DEBUG
        let workspacePath = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fuckify.xcodeproj")
            .appendingPathComponent("project.xcworkspace")
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("swiftpm")
            .appendingPathComponent("Package.resolved")
        
        if let data = try? Data(contentsOf: workspacePath),
           let acknowList = try? AcknowPackageDecoder().decode(from: data) {
            return acknowList
        }
        #endif
        
        return nil
    }
}
/*
#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
*/
