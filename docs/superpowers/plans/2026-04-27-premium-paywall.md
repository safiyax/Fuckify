# Premium Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Premium subscription paywall (monthly + annual) behind a feature flag in the Experiments section, with a custom aspirational paywall sheet, a management sheet for existing subscribers, and a `PremiumManager` singleton that owns all StoreKit 2 logic.

**Architecture:** `PremiumManager` (`@Observable @MainActor` singleton) owns product loading, purchase, restore, and entitlement checking for both product IDs. `PaywallView` is a full-screen custom scroll view with a plan picker and emotional copy. `PremiumManagementView` is a `.medium` detent sheet for existing subscribers. Both are gated behind `settings.more.experiments.paywall` feature flag.

**Tech Stack:** StoreKit 2 (`Product`, `Transaction`, `AppStore`), SwiftUI, `@Observable`, existing `IAPStateManager`, existing `FeatureFlagsProvider` pattern.

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `Fuckify/Core/Store/PremiumManager.swift` | **Create** | StoreKit 2 product loading, purchase, restore, entitlement state |
| `Fuckify/Features/Premium/PremiumFeatureRow.swift` | **Create** | Shared subview: icon + title + optional description |
| `Fuckify/Features/Premium/PaywallView.swift` | **Create** | Full-screen paywall: hero, feature list, plan picker, CTA |
| `Fuckify/Features/Premium/PremiumManagementView.swift` | **Create** | `.medium` sheet for active subscribers |
| `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift` | **Modify** | Add `settingsMoreExperimentsPaywall` key + `ExperimentsFlags.paywall` |
| `Fuckify/Features/Experiments/ExperimentsView.swift` | **Modify** | Add Paywall row, inject `PremiumManager` from environment |
| `Fuckify/Features/Settings/Debug/DebugMenuView.swift` | **Modify** | Add `settings.more.experiments.paywall` flag row + "Reset Premium" debug button |
| `Fuckify/FuckifyApp.swift` | **Modify** | Instantiate `PremiumManager`, inject into environment, start `listenForTransactions()` |
| `Fuckify/Features/Settings/Store/SupportView.swift` | **Modify** | Update privacy copy |

---

## Task 1: `PremiumManager`

**Files:**
- Create: `Fuckify/Core/Store/PremiumManager.swift`

- [ ] **Step 1: Create `PremiumManager.swift`**

```swift
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
```

- [ ] **Step 2: Build and verify no errors**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Core/Store/PremiumManager.swift
git commit -m "feat: add PremiumManager with StoreKit 2 product loading, purchase, restore"
```

---

## Task 2: Inject `PremiumManager` into the environment

**Files:**
- Modify: `Fuckify/FuckifyApp.swift`

- [ ] **Step 1: Add `premiumManager` state and inject into environment**

In `FuckifyApp.swift`, add after the `featureFlags` state property:

```swift
@State private var premiumManager = PremiumManager.shared
```

Then in the `.task` modifier on `ContentView()` (currently around line 135–138), add the call to start transaction listening and load:

```swift
.task {
    await stiManager.load()
    await featureFlags.load()
    premiumManager.startListeningForTransactions()
}
```

And add `.environment(premiumManager)` alongside the other environment injections on `ContentView()`:

```swift
.environment(premiumManager)
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/FuckifyApp.swift
git commit -m "feat: inject PremiumManager into SwiftUI environment"
```

---

## Task 3: Feature flag wiring

**Files:**
- Modify: `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift`

- [ ] **Step 1: Add the flag key**

In the `FeatureFlagKey` enum, add after `settingsMoreExperimentsUserRegistration`:

```swift
case settingsMoreExperimentsPaywall = "settings.more.experiments.paywall"
```

- [ ] **Step 2: Add the computed property to `ExperimentsFlags`**

In `struct ExperimentsFlags`, add:

```swift
var paywall: Bool { provider.isEnabled(.settingsMoreExperimentsPaywall) }
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift
git commit -m "feat: add settings.more.experiments.paywall feature flag"
```

---

## Task 4: `PremiumFeatureRow` shared subview

**Files:**
- Create: `Fuckify/Features/Premium/PremiumFeatureRow.swift`

- [ ] **Step 1: Create `PremiumFeatureRow.swift`**

```swift
//
//  PremiumFeatureRow.swift
//  Fuckify
//

import SwiftUI

struct PremiumFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    var description: String? = nil

    var body: some View {
        HStack(alignment: description != nil ? .top : .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Premium/PremiumFeatureRow.swift
git commit -m "feat: add PremiumFeatureRow shared subview"
```

---

## Task 5: `PaywallView`

**Files:**
- Create: `Fuckify/Features/Premium/PaywallView.swift`

- [ ] **Step 1: Create `PaywallView.swift`**

```swift
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
        ("figure.run",                 .orange,  "Streaks & Dry Spells", "Know your rhythms."),
        ("rectangle.stack.fill",       .blue,    "Widgets",              "At a glance, privately."),
        ("heart.text.square.fill",     .pink,    "HealthKit",            "Connect to your health picture."),
        ("photo.on.rectangle",         .teal,    "Extra Icons",          "Make it yours."),
        ("arrow.triangle.2.circlepath",.indigo,  "Partner Sync",         "Share history with people you trust."),
        ("person.3.fill",              .mint,    "Group Sync",           "For the adventurous."),
        ("trophy.fill",                .yellow,  "Leaderboards",         "Friendly competition."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                    .padding(.bottom, 32)

                VStack(spacing: 0) {
                    featureList
                        .padding(.horizontal)
                        .padding(.bottom, 32)

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
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await premium.load() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.accentColor, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Spacer(minLength: 60)

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
        .frame(minHeight: 280)
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 16) {
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
        if let monthly = premium.monthlyProduct, let annual = premium.annualProduct {
            HStack(spacing: 12) {
                planCard(
                    product: annual,
                    badge: "Best Value",
                    period: "/ year",
                    isSelected: premium.selectedProduct?.id == annual.id
                )
                planCard(
                    product: monthly,
                    badge: nil,
                    period: "/ month",
                    isSelected: premium.selectedProduct?.id == monthly.id
                )
            }
        }
    }

    private func planCard(product: Product, badge: String?, period: String, isSelected: Bool) -> some View {
        Button {
            premium.selectedProduct = product
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }

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
                    LinearGradient(
                        colors: [.accentColor, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
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
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Premium/PaywallView.swift
git commit -m "feat: add PaywallView with plan picker and aspirational copy"
```

---

## Task 6: `PremiumManagementView`

**Files:**
- Create: `Fuckify/Features/Premium/PremiumManagementView.swift`

- [ ] **Step 1: Create `PremiumManagementView.swift`**

```swift
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

                            if let date = premium.renewalDate {
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
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Premium/PremiumManagementView.swift
git commit -m "feat: add PremiumManagementView subscriber management sheet"
```

---

## Task 7: Wire into `ExperimentsView`

**Files:**
- Modify: `Fuckify/Features/Experiments/ExperimentsView.swift`

- [ ] **Step 1: Replace `ExperimentsView.swift` with the updated version**

```swift
//
//  ExperimentsView.swift
//  Fuckify

import SwiftUI

struct ExperimentsView: View {
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @Environment(PremiumManager.self) private var premium
    @State private var registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
    @State private var showManagement = false

    var body: some View {
        Group {
            if featureFlags.settings.more.experimentsFlags.userRegistration ||
               featureFlags.settings.more.experimentsFlags.paywall {
                Form {
                    if featureFlags.settings.more.experimentsFlags.userRegistration {
                        Section {
                            if let username = registeredUsername {
                                LabeledContent("User Registration", value: "Registered as @\(username)")
                            } else {
                                NavigationLink("User Registration") {
                                    RegistrationContainerView()
                                }
                            }
                        }
                    }

                    if featureFlags.settings.more.experimentsFlags.paywall {
                        Section {
                            if premium.isPremium {
                                LabeledContent("Premium", value: "Active")
                                    .contentShape(Rectangle())
                                    .onTapGesture { showManagement = true }
                            } else {
                                NavigationLink("Premium") {
                                    PaywallView()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
            }
        }
        .navigationTitle("Experiments")
        .onAppear {
            registeredUsername = UserDefaults.standard.string(forKey: "cc.username")
        }
        .task {
            await premium.load()
        }
        .sheet(isPresented: $showManagement) {
            PremiumManagementView()
                .environment(premium)
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentsView()
            .environment(FeatureFlagsProvider())
            .environment(PremiumManager.shared)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Experiments/ExperimentsView.swift
git commit -m "feat: add Premium row to ExperimentsView"
```

---

## Task 8: Debug menu additions

**Files:**
- Modify: `Fuckify/Features/Settings/Debug/DebugMenuView.swift`

- [ ] **Step 1: Add paywall flag row to the `settings.more.experiments` section**

In `DebugMenuView.swift`, find the `settings.more.experiments` section and add after the `userRegistration` row:

```swift
flagRow("  paywall",
        key: "settings.more.experiments.paywall",
        current: featureFlags.settings.more.experimentsFlags.paywall)
```

- [ ] **Step 2: Add "Reset Premium" debug button to the Registration section**

In `DebugMenuView.swift`, find the Registration section and add a second button after "Reset Login State":

```swift
Button(role: .destructive) {
    showResetPremiumConfirm = true
} label: {
    HStack {
        Image(systemName: "crown.slash")
        Text("Reset Premium State")
    }
}
```

Add `.confirmationDialog` for it below the existing one:

```swift
.confirmationDialog(
    "Reset Premium State?",
    isPresented: $showResetPremiumConfirm,
    titleVisibility: .visible
) {
    Button("Reset", role: .destructive) { resetPremiumState() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Forces a fresh entitlement check. Use this to simulate a non-subscriber in the simulator.")
}
```

- [ ] **Step 3: Add state variable and helper**

Add to the `@State` properties:

```swift
@State private var showResetPremiumConfirm = false
```

Add to the helpers section:

```swift
private func resetPremiumState() {
    // Force re-check on next load — no local cache to clear since PremiumManager
    // always checks Transaction.currentEntitlements live. Just reload.
    Task { await premiumManager.load() }
}
```

Add `@Environment(PremiumManager.self) private var premiumManager` to the environment properties at the top of `DebugMenuView`.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Fuckify/Features/Settings/Debug/DebugMenuView.swift
git commit -m "feat: add paywall flag row and Reset Premium button to debug menu"
```

---

## Task 9: Update `SupportView` privacy copy

**Files:**
- Modify: `Fuckify/Features/Settings/Store/SupportView.swift`

- [ ] **Step 1: Update the copy**

Find the `FeatureRow` with `description: "No ads, no tracking, no subscriptions"` and change it to:

```swift
FeatureRow(
    icon: "lock.shield.fill",
    color: .green,
    title: "Privacy First",
    description: "No ads, no tracking, your data stays on device."
)
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Settings/Store/SupportView.swift
git commit -m "fix: update SupportView privacy copy to not mention subscriptions"
```

---

## Testing Checklist

After all tasks are complete, verify the following manually in the simulator with the `.storekit` config active:

- [ ] `settings.more.experiments.paywall` flag off → Paywall row not visible in Experiments
- [ ] Flag on → "Premium" NavigationLink visible
- [ ] Tapping "Premium" → `PaywallView` opens with hero, feature list, plan picker, CTA
- [ ] Annual card is preselected by default
- [ ] Tapping Monthly card selects it; subscribe button updates price
- [ ] Tapping subscribe → StoreKit purchase sheet appears (simulator)
- [ ] After purchase → row shows "Active", tapping opens `PremiumManagementView`
- [ ] "Manage Subscription" button deep-links to iOS Settings
- [ ] "Restore Purchases" works
- [ ] Debug "Reset Premium State" → re-checks entitlements
- [ ] Debug "Reset Login State" unrelated — still works
