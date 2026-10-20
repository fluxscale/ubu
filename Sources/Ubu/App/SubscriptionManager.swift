#if APP_STORE
import AppKit
import StoreKit

/// The App Store build's yearly subscription (StoreKit 2). The free trial is an
/// introductory offer configured in App Store Connect, so no trial logic lives here.
@MainActor
final class SubscriptionManager {
    static let productID = "com.fluxscale.ubu.yearly"

    private(set) var isSubscribed = false
    private(set) var product: Product?
    private(set) var isEligibleForTrial = false
    private var productLoadError: Error?

    /// Called after every entitlement check, so the first call carries the initial state.
    var onChange: (() -> Void)?

    private var updatesTask: Task<Void, Never>?

    func start() {
        // Renewals, refunds, and purchases made on another Mac arrive here.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active

        if product == nil {
            do {
                product = try await Product.products(for: [Self.productID]).first
                productLoadError = nil
                if product == nil {
                    Log.app.error("App Store returned no product for \(Self.productID, privacy: .public)")
                }
            } catch {
                productLoadError = error
                Log.app.error("Product lookup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        isEligibleForTrial = await product?.subscription?.isEligibleForIntroOffer ?? false
        onChange?()
    }

    var purchaseTitle: String {
        guard let product else { return "Subscribe…" }
        return isEligibleForTrial
            ? "Start Free Trial…"
            : "Subscribe — \(product.displayPrice)/year…"
    }

    /// Shown above the purchase button, e.g. "Free for 1 week, then $1.99/year."
    var offerDescription: String {
        guard let product, let subscription = product.subscription else {
            return "Yearly subscription"
        }
        let price = "\(product.displayPrice)/\(Self.unitName(subscription.subscriptionPeriod.unit))"
        if isEligibleForTrial, let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial {
            return "Free for \(Self.describe(offer.period)), then \(price). Cancel anytime."
        }
        return "\(price)."
    }

    static func describe(_ period: Product.SubscriptionPeriod) -> String {
        describe(value: period.value, unit: unitName(period.unit))
    }

    static func describe(value: Int, unit: String) -> String {
        value == 1 ? "1 \(unit)" : "\(value) \(unit)s"
    }

    static func unitName(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }

    /// `window` hosts Apple's payment sheet; without one a menu-bar app's purchase stalls.
    func purchase(in window: NSWindow) async {
        if product == nil { await refresh() }
        guard let product else {
            if let productLoadError {
                showAlert("Couldn't Reach the App Store", productLoadError.localizedDescription)
            } else {
                // Reached the store, but it has nothing to sell: the product isn't live for this
                // build yet (agreements, metadata, or propagation), not a connection problem.
                showAlert("Subscription Not Available Yet",
                          "The App Store didn't return ubu's subscription. Please try again later.")
            }
            return
        }
        do {
            let result: Product.PurchaseResult
            if #available(macOS 15.2, *) {
                result = try await product.purchase(confirmIn: window)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                result = try await product.purchase()
            }
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refresh()
            case .success(.unverified(_, let error)):
                showAlert("Purchase Couldn't Be Verified", error.localizedDescription)
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            showAlert("Purchase Failed", error.localizedDescription)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            showAlert("Restore Failed", error.localizedDescription)
        }
        await refresh()
        if !isSubscribed {
            showAlert("No Subscription Found", "This Apple Account has no active ubu subscription.")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
#endif
