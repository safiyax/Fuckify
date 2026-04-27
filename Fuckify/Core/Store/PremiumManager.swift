//
//  PremiumManager.swift
//  Fuckify
//

import Foundation
import StoreKit

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "Premium")

private let monthlyProductID = "baby.safi.Fuckify.premium.monthly"
private let annualProductID  = "baby.safi.Fuckify.premium.annual"

@Observable
@MainActor
final class PremiumManager {
    static let shared = PremiumManager()

    // MARK: - State

    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var isPremium = false
    private(set) var monthlyProduct: Product? = nil
    private(set) var annualProduct: Product? = nil
    private(set) var loadError: String? = nil
    private(set) var renewalDate: Date? = nil

    /// Which product the user has selected in the paywall. Annual is preselected (better value).
    var selectedProduct: Product? {
        get { _selectedProduct ?? annualProduct ?? monthlyProduct }
        set { _selectedProduct = newValue }
    }
    private var _selectedProduct: Product? = nil

    private var transactionListenerTask: Task<Void, Never>? = nil

    private init() {}

    // MARK: - Load

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [monthlyProductID, annualProductID])
            for product in products {
                switch product.id {
                case monthlyProductID: monthlyProduct = product
                case annualProductID:  annualProduct  = product
                default: break
                }
            }
            logger.info("Loaded \(products.count) premium product(s)")
        } catch {
            loadError = "Couldn't load subscription options. Check your connection and try again."
            logger.error("Product load failed: \(error)")
        }

        await refreshEntitlements()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        IAPStateManager.shared.isIAPInProgress = true
        defer {
            isPurchasing = false
            IAPStateManager.shared.isIAPInProgress = false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                await refreshEntitlements()
                logger.info("Purchase succeeded: \(transaction.productID)")
            case .userCancelled:
                logger.info("Purchase cancelled by user")
            case .pending:
                logger.info("Purchase pending (Ask to Buy / SCA)")
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error)")
        }
    }

    // MARK: - Restore

    func restore() async {
        isPurchasing = true
        IAPStateManager.shared.isIAPInProgress = true
        defer {
            isPurchasing = false
            IAPStateManager.shared.isIAPInProgress = false
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            logger.info("Restore completed")
        } catch {
            logger.error("Restore failed: \(error)")
        }
    }

    // MARK: - Transaction listener

    func startListeningForTransactions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try result.payloadValue
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    logger.error("Transaction update error: \(error)")
                }
            }
        }
    }

    // MARK: - Entitlement check

    private func refreshEntitlements() async {
        var found = false
        var latestExpiry: Date? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == monthlyProductID || transaction.productID == annualProductID {
                found = true
                if let expiry = transaction.expirationDate {
                    if latestExpiry == nil || expiry > latestExpiry! {
                        latestExpiry = expiry
                    }
                }
            }
        }

        isPremium = found
        renewalDate = latestExpiry
        logger.info("Entitlement check: isPremium=\(found), renewalDate=\(String(describing: latestExpiry))")
    }
}
