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

    func purchase() async {
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
            switch try await product.purchase() {
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
