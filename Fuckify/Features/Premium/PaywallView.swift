//
//  PaywallView.swift
//  Fuckify
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, color: Color, title: String, description: String)] = [
        ("chart.bar.fill",             .purple,  "Rich Stats",           "See patterns in your own time."),
//        ("figure.run",                 .orange,  "Streaks & Dry Spells", "Know your rhythms."),
        ("rectangle.stack.fill",       .blue,    "Widgets",              "At a glance, privately."),
        ("heart.text.square.fill",     .pink,    "HealthKit",            "Connect to your health picture."),
        ("photo.on.rectangle",         .teal,    "Extra Icons",          "Make it yours."),
        ("arrow.triangle.2.circlepath",.indigo,  "Partner Sync",         "Share history with people you trust."),
//        ("person.3.fill",              .mint,    "Group Sync",           "For the adventurous."),
        ("trophy.fill",                .yellow,  "Leaderboards",         "Friendly competition."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            heroSection
                .padding(.bottom, 16)
            
            VStack(spacing: 0) {
                featureList
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                planPicker
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                subscribeButton
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                restoreButton
                    .padding(.bottom, 12)
                
                legalFooter
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task { await premium.load() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
//            LinearGradient(
//                colors: [.accentColor, .purple],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
            AnimatedBlobBackground(movementSpeed: 5.0)

            VStack(spacing: 16) {
                Spacer(minLength: 20)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 8) {
                    Text("Your intimacy, your history, your data.")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Premium unlocks everything — for you and the people you choose to share with.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 32)
            }
        }
        .frame(minHeight: 240)
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.title) { feature in
                PremiumFeatureRow(
                    icon: feature.icon,
                    color: feature.color,
                    title: feature.title,
                    description: feature.description
                )
            }
        }
    }

    // MARK: - Plan picker

    @ViewBuilder
    private var planPicker: some View {
        VStack(spacing: 12) {
            if let monthly = premium.monthlyProduct, let annual = premium.annualProduct, let lifetime = premium.lifetimeProduct {
                HStack(spacing: 12) {
                    planCard(
                        product: monthly,
                        badge: nil,
                        period: "/ month",
                        isSelected: premium.selectedProduct?.id == monthly.id
                    )
                    planCard(
                        product: annual,
                        badge: "Best Value",
                        period: "/ year",
                        isSelected: premium.selectedProduct?.id == annual.id
                    )
                    planCard(
                        product: lifetime,
                        badge: "One-Time",
                        period: "forever",
                        isSelected: premium.selectedProduct?.id == lifetime.id
                    )
                }
            }
        }
    }

    private func planCard(product: Product, badge: String?, period: String, isSelected: Bool) -> some View {
        Button {
            premium.selectedProduct = product
        } label: {
            VStack(spacing: 6) {
//                if let badge {
                    Text(badge ?? "")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge != nil ? Color.accentColor : .clear)
                        .clipShape(Capsule())
//                }

                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe button

    @ViewBuilder
    private var subscribeButton: some View {
        if premium.isPremium {
            Text("You're already premium.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else if premium.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if let error = premium.loadError {
            VStack(spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await premium.load() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else if let product = premium.selectedProduct {
            Button {
                Task { await premium.purchase(product) }
            } label: {
                Group {
                    if premium.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Subscribe for \(product.displayPrice)")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
//                    LinearGradient(
//                        colors: [.accentColor, .purple],
//                        startPoint: .leading,
//                        endPoint: .trailing
//                    )
                    AnimatedBlobBackground(movementSpeed: 5.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(premium.isPurchasing)
        }
    }

    // MARK: - Restore & legal

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await premium.restore() }
        }
        .font(.subheadline)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(premium.isPurchasing)
    }

    private var legalFooter: some View {
        Text("Subscription auto-renews. Cancel anytime in iOS Settings.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    NavigationStack {
        PaywallView()
            .environment(PremiumManager.shared)
    }
}
