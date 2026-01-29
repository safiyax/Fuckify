//
//  SupportView.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-01-27.
//

import SwiftUI
import StoreKit
import Combine
import Foundation

struct SupportView: View {
    @StateObject private var store = SupportViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Support Development")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Enjoying Coital Comrade? Buy me a coffee to support continued development and new features!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Coffee Options
                    VStack(spacing: 16) {
                        if let product = store.product {
                            // Coffee Button
                            Button {
                                store.isPurchasing = false
                                Task { await store.purchase() }
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: store.purchaseSuccess ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.purchaseSuccess ? "Thank You!" : product.displayName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text(store.purchaseSuccess ? "You're amazing!" : product.description)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(store.purchaseSuccess ? "❤️" : product.displayPrice)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: store.purchaseSuccess ? [.green, .green.opacity(0.8)] : [.accentColor, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .disabled(store.purchaseSuccess)
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .animation(.easeInOut, value: store.purchaseSuccess)
                        } else {
                            // Loading state
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("Loading store...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    
                    // Info Section
                    VStack(spacing: 20) {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Why Support?")
                                .font(.headline)
                            
                            FeatureRow(
                                icon: "sparkles",
                                color: .yellow,
                                title: "New Features",
                                description: "Help fund development of new features"
                            )
                            
                            FeatureRow(
                                icon: "wrench.and.screwdriver.fill",
                                color: .blue,
                                title: "Bug Fixes",
                                description: "Keep the app running smoothly"
                            )
                            
                            FeatureRow(
                                icon: "lock.shield.fill",
                                color: .green,
                                title: "Privacy First",
                                description: "No ads, no tracking, no subscriptions"
                            )
                            
                            FeatureRow(
                                icon: "heart.fill",
                                color: .pink,
                                title: "Show Love",
                                description: "Support independent development"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Coffee Counter
                    if store.coffeeCount > 0 {
                        VStack(spacing: 12) {
                            Divider()
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.brown, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Coffees Purchased")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("\(store.coffeeCount) \(store.coffeeCount == 1 ? "coffee" : "coffees") ☕")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
//                    #if DEBUG
//                    // Debug: Simulate purchase in simulator
//                    Button("Debug: Simulate Coffee Purchase") {
//                        Task {
//                            let current = UserDefaults.standard.integer(forKey: "dev_coffeesPurchased")
//                            UserDefaults.standard.set(current + 1, forKey: "dev_coffeesPurchased")
//                            await store.loadCoffeeCount()
//                            store.purchaseSuccess = true
//                        }
//                    }
//                    .buttonStyle(.bordered)
//                    .padding(.horizontal)
//                    
//                    Button("Debug: Reset Counter") {
//                        Task {
//                            UserDefaults.standard.set(0, forKey: "dev_coffeesPurchased")
//                            await store.loadCoffeeCount()
//                            store.purchaseSuccess = false
//                        }
//                    }
//                    .buttonStyle(.bordered)
//                    .padding(.horizontal)
//                    #endif
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Support the App")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Reset success state when view appears
                store.resetSuccessState()
            }
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button {
//                        dismiss()
//                    } label: {
//                        Label("Close", systemImage: "xmark")
//                    }
//                }
//            }
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

@MainActor
final class SupportViewModel: ObservableObject {
    private let productIdentifier = "buymeacoffee"
    
    @Published var product: Product?
    @Published var purchaseSuccess = false
    @Published var coffeeCount = 0
    @Published var isPurchasing = false
    
    init() {
        Task {
            await loadProduct()
            await loadCoffeeCount()
        }
        
        // Start listening for transactions
        listenForTransactions()
    }
    
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productIdentifier])
            if let loaded = products.first {
                product = loaded
                print("✅ Product loaded: \(loaded.id) - \(loaded.displayName)")
            } else {
                print("⚠️ No product found for ID: \(productIdentifier)")
                print("⚠️ Make sure product ID matches App Store Connect exactly")
            }
        } catch {
            print("❌ Failed to load product: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
        }
    }
    
    func loadCoffeeCount() async {
        var count = 0
        
        // Iterate through all transactions for this product
        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result,
               transaction.productID == productIdentifier,
               transaction.revocationDate == nil {
                count += 1
            }
        }
        
        #if DEBUG
        // Fallback to UserDefaults in simulator/development
        if count == 0 {
            count = UserDefaults.standard.integer(forKey: "dev_coffeesPurchased")
        }
        #endif
        
        coffeeCount = count
    }
    
    func purchase() async {
        guard let product else { return }
        
        // Disable biometric auto-prompt while IAP is active
        isPurchasing = true
        
        if case .success(let result) = try? await product.purchase(),
           case .verified(let transaction) = result {
            await handleTransaction(transaction)
        }
        
        // Re-enable biometric auto-prompt after IAP completes
        isPurchasing = false
    }
    
    func resetSuccessState() {
        purchaseSuccess = false
    }
    
    private func handleTransaction(_ transaction: StoreKit.Transaction) async {
        // Finish the transaction
        await transaction.finish()
        
        #if DEBUG
        // Increment dev counter for simulator testing
        let current = UserDefaults.standard.integer(forKey: "dev_coffeesPurchased")
        UserDefaults.standard.set(current + 1, forKey: "dev_coffeesPurchased")
        #endif
        
        // Reload coffee count from transaction history
        await loadCoffeeCount()
        
        // Show success state (persists until view is dismissed)
        purchaseSuccess = true
    }
    
    private func listenForTransactions() {
        Task {
            for await update in StoreKit.Transaction.updates {
                if case .verified(let transaction) = update,
                   transaction.productID == productIdentifier {
                    await handleTransaction(transaction)
                }
            }
        }
    }
}

#Preview {
    SupportView()
}
