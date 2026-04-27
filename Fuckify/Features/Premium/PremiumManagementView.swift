//
//  PremiumManagementView.swift
//  Fuckify
//

import SwiftUI

struct PremiumManagementView: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String)] = [
        ("chart.bar.fill",              "Rich Stats"),
        ("figure.run",                  "Streaks & Dry Spells"),
        ("rectangle.stack.fill",        "Widgets"),
        ("heart.text.square.fill",      "HealthKit"),
        ("photo.on.rectangle",          "Extra Icons"),
        ("arrow.triangle.2.circlepath", "Partner Sync"),
        ("person.3.fill",               "Group Sync"),
        ("trophy.fill",                 "Leaderboards"),
    ]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Status
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("You're Premium")
                                .font(.headline)

                            if let date = premium.expirationDate {
                                Text("Renews \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: Feature summary
                Section("Included Features") {
                    ForEach(features, id: \.title) { feature in
                        PremiumFeatureRow(icon: feature.icon, color: .accentColor, title: feature.title)
                    }
                }

                // MARK: Actions
                Section {
                    Button {
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Manage Subscription", systemImage: "arrow.up.right.square")
                    }

                    Button {
                        Task { await premium.restore() }
                    } label: {
                        if premium.isPurchasing {
                            HStack {
                                ProgressView()
                                Text("Restoring...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(premium.isPurchasing)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    PremiumManagementView()
        .environment(PremiumManager.shared)
}
