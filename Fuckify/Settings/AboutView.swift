//
//  AboutView.swift
//  Fuckify
//
//

import SwiftUI
import AcknowList

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    // App Icon
                    if let appIcon = UIImage(named: "CatIcon60x60-Image") {
                        Image(uiImage: appIcon)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                    } else {
                        Circle()
                            .fill(Color("AccentColor"))
                            .overlay {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .offset(y: 3)
                            }
                            .frame(width: 100, height: 100)
                    }

                    // App Name
                    Text("Fuckify")
                        .font(.title)
                        .fontWeight(.bold)

                    // Version Info
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)

            Section("Creator") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.pink)
                    Text("Safiya Hooda")
                    Spacer()
                }
            }

            Section {
                Text("Fuckify is a sexual health companion app designed to help you track your encounters and maintain your wellness.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section("Open Source") {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    HStack {
//                        Image(systemName: "heart.text.square.fill")
//                            .foregroundColor(.red)
                        Text("Acknowledgements")
                    }
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
