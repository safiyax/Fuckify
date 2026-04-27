# Premium Paywall — Design Spec

**Date:** 2026-04-27  
**Status:** Approved  
**Product IDs:**
- `baby.safi.Fuckify.premium.monthly` (1 month)
- `baby.safi.Fuckify.premium.annual` (1 year)

---

## Overview

Add a Premium subscription paywall behind a feature flag in the Experiments section. The paywall is the first step toward monetising server-backed and power-user features. It is gated behind `settings.more.experiments.paywall` so it can be tested in isolation before being promoted to the main app.

Two subscription options: monthly (`baby.safi.Fuckify.premium.monthly`) and annual (`baby.safi.Fuckify.premium.annual`). Both unlock the same set of premium features. Annual is presented as the better value option.

---

## Premium Features

| Feature | Description |
|---|---|
| Rich Stats | Extended analytics and pattern visualisation |
| Streaks & Dry Spells | Frequency tracking and gap awareness |
| Widgets | Home/lock screen widgets |
| HealthKit | Read/write integration with Apple Health |
| Extra Icons | Additional app icon options |
| Partner Sync | E2EE encounter history sync with partners |
| Group Sync | Multi-partner group history sync |
| Leaderboards | Opt-in friend leaderboards |

---

## Architecture

### `PremiumManager` (`Fuckify/Core/Store/PremiumManager.swift`)

`@Observable @MainActor` singleton. Injected into the SwiftUI environment in `FuckifyApp.swift` alongside `SecuritySettings`.

**State:**

```swift
var isLoading: Bool             // product fetch in progress
var isPurchasing: Bool          // purchase flow in progress
var isPremium: Bool             // active entitlement exists for either product
var monthlyProduct: Product?    // baby.safi.Fuckify.premium.monthly
var annualProduct: Product?     // baby.safi.Fuckify.premium.annual
var loadError: String?          // shown in paywall if fetch fails
var renewalDate: Date?          // from latest transaction, shown in management view
var selectedProduct: Product?   // which option the user has chosen in the paywall UI
```

**Responsibilities:**

- `load()` — fetches both products via `Product.products(for: [monthlyID, annualID])`, checks `Transaction.currentEntitlements` for either product ID to set `isPremium` and `renewalDate`. Called from `.task` in `ExperimentsView`. Sets `selectedProduct` to the annual product by default (better value preselected).
- `purchase(product:)` — calls `product.purchase()` on the passed product, manages `isPurchasing` and feeds `IAPStateManager.shared.isIAPInProgress` (prevents app lock during purchase). Handles `.success`, `.userCancelled`, `.pending`.
- `restore()` — calls `AppStore.sync()`, re-checks entitlements.
- `listenForTransactions()` — long-lived background `Task` on `Transaction.updates`, keeps `isPremium` live after purchase or cancellation.

`isPurchasing` is mirrored to `IAPStateManager.shared.isIAPInProgress` via `onChange` or direct assignment, consistent with how `SupportView` handles it.

---

## Feature Flag

New flag: `settings.more.experiments.paywall` (Bool, default `false`).

Added to:
- `ExperimentsFlags` struct in `FeatureFlagsProvider.swift`
- `ExperimentsView` row (gated behind this flag)
- `DebugMenuView` under the `settings.more.experiments` section

---

## `ExperimentsView` Integration

The Paywall row reads `isPremium` from `@Environment(PremiumManager.self)`.

- **Not subscribed:** `NavigationLink("Premium") { PaywallView() }`
- **Subscribed:** `LabeledContent("Premium", value: "Active")` with `.onTapGesture { showManagement = true }` presenting `PremiumManagementView` as a sheet

`.task` on `ExperimentsView` calls `premiumManager.load()` — fires once per view lifetime, cancels on disappear.

---

## `PaywallView` (`Fuckify/Features/Premium/PaywallView.swift`)

Full-screen `ScrollView`. Emotional/aspirational tone. Matches `SupportView` gradient + card aesthetic.

**Layout (top to bottom):**

1. **Hero section**
   - Gradient background: `.accentColor → .purple` (matches `SupportView`)
   - Icon: `heart.circle.fill` at 80pt
   - Headline: *"Your intimacy, your history, your data."*
   - Subheadline: *"Premium unlocks everything — for you and the people you choose to share with."*

2. **Feature list** — `PremiumFeatureRow` subview (icon + title + one-line description):

   | Icon | Title | Copy |
   |---|---|---|
   | `chart.bar.fill` | Rich Stats | *"See patterns in your own time."* |
   | `figure.run` | Streaks & Dry Spells | *"Know your rhythms."* |
   | `rectangle.stack.fill` | Widgets | *"At a glance, privately."* |
   | `heart.text.square.fill` | HealthKit | *"Connect to your health picture."* |
   | `photo.on.rectangle` | Extra Icons | *"Make it yours."* |
   | `arrow.triangle.2.circlepath` | Partner Sync | *"Share history with people you trust."* |
   | `person.3.fill` | Group Sync | *"For the polycules."* |
   | `trophy.fill` | Leaderboards | *"Friendly competition."* |

3. **Plan picker** — two tappable cards side by side, monthly and annual. Annual is preselected and badged *"Best Value"*. Each card shows the product's `displayPrice` and period. Selecting a card updates `premiumManager.selectedProduct`.

4. **Subscribe button** — full-width gradient pill (`.accentColor → .purple`):
   - Loaded: `"Subscribe for {selectedProduct.displayPrice}"` 
   - Loading products: `ProgressView`
   - Error: error message + "Retry" button
   - Purchasing: disabled + `ProgressView`
   - Already premium (edge case): static "You're already premium" message

5. **Restore Purchases** — `.plain` text button below CTA, calls `premiumManager.restore()`

6. **Legal footer** — `.caption` text: *"Subscription auto-renews. Cancel anytime in iOS Settings."*

---

## `PremiumManagementView` (`Fuckify/Features/Premium/PremiumManagementView.swift`)

Compact sheet. `.presentationDetents([.medium])`. No explicit close button — drag to dismiss.

**Layout:**

1. **Status header** — green checkmark icon, *"You're Premium"*, renewal date if available (*"Renews [date]"*) otherwise *"Active"*
2. **Feature summary** — condensed read-only list (icon + title only, no descriptions)
3. **Manage Subscription** — opens `itms-apps://apps.apple.com/account/subscriptions` via `UIApplication.shared.open`
4. **Restore Purchases** — calls `premiumManager.restore()`, shows `ProgressView` while in progress

---

## `SupportView` Copy Update

The `FeatureRow` with `description: "No ads, no tracking, no subscriptions"` is updated to:

> *"No ads, no tracking, your data stays on device."*

This is accurate once a subscription exists and avoids misleading new users.

---

## File Structure

```
Fuckify/
├── Core/
│   └── Store/
│       └── PremiumManager.swift          # new
└── Features/
    └── Premium/
        ├── PaywallView.swift             # new
        ├── PremiumFeatureRow.swift       # new (shared subview)
        └── PremiumManagementView.swift   # new
```

Modified files:
- `FuckifyApp.swift` — inject `PremiumManager` into environment
- `FeatureFlagsProvider.swift` — add `paywall` to `ExperimentsFlags`
- `ExperimentsView.swift` — add Paywall row
- `DebugMenuView.swift` — add `settings.more.experiments.paywall` flag row
- `SupportView.swift` — update privacy copy

---

## StoreKit Testing

Uses the existing StoreKit configuration pattern in the project. `.storekit` config file entries for both `baby.safi.Fuckify.premium.monthly` and `baby.safi.Fuckify.premium.annual` must be added for simulator testing. The `DebugMenuView` "Reset Login State" pattern is the model for any debug-only purchase reset tooling needed — a "Reset Premium" debug button should be added to clear the local entitlement cache and force a re-check.

---

## Out of Scope

- Paywall enforcement on individual features (that comes after this experiment graduates)
- Server-side receipt validation
- Subscription analytics / conversion tracking
