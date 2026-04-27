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

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "IAP")

// MARK: - Shared IAP State Manager

@MainActor
final class IAPStateManager: ObservableObject {
    static let shared = IAPStateManager()
    @Published var isIAPInProgress: Bool = false
    
    private init() {}
}

struct SupportView: View {
    @StateObject private var store = SupportViewModel()
    @StateObject private var iapState = IAPStateManager.shared
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
                    coffeeSection
                    
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
                                description: "No ads, no tracking, your data stays on device."
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
            .dismissOnAppLock()
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
        .onChange(of: store.isPurchasing) { oldValue, newValue in
            logger.info("IAP purchasing state changed: \(oldValue) -> \(newValue)")
            iapState.isIAPInProgress = newValue  // Update shared state
        }
    }

    @ViewBuilder
    private var coffeeSection: some View {
        VStack(spacing: 16) {
            if let product = store.product {
                Button {
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
            } else if let message = store.loadErrorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)

                    Text("Store Unavailable")
                        .font(.headline)

                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 10) {
                        Button("Retry") {
                            Task { await store.loadProduct() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Restore") {
                            Task { await store.syncAppStore() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
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
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // Product IDs to try (in order of preference)
    // Try both with and without bundle ID prefix
    private let productIdentifiers = [
        "baby.safi.Fuckify.buymeacoffee",  // With bundle ID prefix (recommended)
//        "buymeacoffee"                       Without prefix (fallback)
    ]
    
    private var productIdentifier: String {
        productIdentifiers.first ?? "baby.safi.Fuckify.buymeacoffee"
    }
    
    @Published var product: Product?
    @Published var purchaseSuccess = false
    @Published var coffeeCount = 0
    @Published var isPurchasing = false
    @Published var loadState: LoadState = .loading

    var loadErrorMessage: String? {
        if case .failed(let message) = loadState {
            return message
        }
        return nil
    }
    
    init() {
        Task {
            await loadProduct()
            await loadCoffeeCount()
        }
        
        // Start listening for transactions
        listenForTransactions()
    }
    
    func loadProduct() async {
        loadState = .loading
        logger.info("Attempting to load IAP products...")
        logger.info("Trying product IDs: \(self.productIdentifiers.joined(separator: ", "))")
        logger.info("App bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        do {
            let products = try await productsWithTimeout(seconds: 20)
            logger.info("Product.products() returned \(products.count) products")
            
            if let loaded = products.first {
                product = loaded
                loadState = .loaded
                logger.info("✅ Product loaded successfully!")
                logger.info("  ID: \(loaded.id)")
                logger.info("  Name: \(loaded.displayName)")
                logger.info("  Price: \(loaded.displayPrice)")
                logger.info("  Description: \(loaded.description)")
            } else {
                product = nil
                loadState = .failed("No products returned from App Store Connect for configured product IDs.")
                logger.warning("⚠️ No products found for any of the following IDs:")
                for id in self.productIdentifiers {
                    logger.warning("  - \(id)")
                }
                logger.warning("")
                logger.warning("⚠️ Troubleshooting steps:")
                logger.warning("  1. Check App Store Connect - Product ID must match EXACTLY (case-sensitive)")
                logger.warning("  2. Verify 'Paid Applications Agreement' is Active in App Store Connect")
                logger.warning("  3. Ensure Bundle ID matches: baby.safi.Fuckify")
                logger.warning("  4. Wait 15-30 minutes after creating product in App Store Connect")
                logger.warning("  5. Try using local StoreKit config file for testing first")
            }
        } catch {
            product = nil
            loadState = .failed(error.localizedDescription)
            logger.error("❌ Failed to load products from App Store Connect")
            logger.error("Error: \(error.localizedDescription)")
            logger.error("Error type: \(String(describing: type(of: error)))")
            
            // Check if this is a StoreKit config issue
            if error.localizedDescription.contains("Configuration") {
                logger.error("💡 Tip: Make sure StoreKit Configuration is set to 'None' in scheme")
                logger.error("   Xcode → Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration")
            }
        }
    }

    func syncAppStore() async {
        do {
            try await AppStore.sync()
            logger.info("AppStore.sync() completed")
        } catch {
            logger.error("AppStore.sync() failed: \(error.localizedDescription)")
        }

        await loadProduct()
    }
    
    func loadCoffeeCount() async {
        var count = 0
        
        // Iterate through all transactions for any of our product IDs
        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result,
               productIdentifiers.contains(transaction.productID),
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
                   productIdentifiers.contains(transaction.productID) {
                    await handleTransaction(transaction)
                }
            }
        }
    }

    private func productsWithTimeout(seconds: Double) async throws -> [Product] {
        try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                try await Product.products(for: self.productIdentifiers)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw URLError(.timedOut)
            }

            let result = try await group.next() ?? []
            group.cancelAll()
            return result
        }
    }
}

#Preview {
    SupportView()
}
