#if APP_STORE
import AppKit
import StoreKit
import SwiftUI

/// The subscribe window. StoreKit needs a window to attach its payment sheet to (a
/// menu-bar app has none), and App Review wants price, term and links shown before buying.
@MainActor
final class PaywallWindow {
    private var window: NSWindow?
    private let subscription: SubscriptionManager

    init(subscription: SubscriptionManager) {
        self.subscription = subscription
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            window.title = "ubu"
            window.isReleasedWhenClosed = false
            self.window = window
        }
        refresh()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    /// Re-renders with the latest product and eligibility.
    func refresh() {
        guard let window else { return }
        window.contentViewController = NSHostingController(rootView: PaywallView(
            offer: subscription.offerDescription,
            buttonTitle: subscription.purchaseTitle.replacingOccurrences(of: "…", with: ""),
            purchase: { [weak self] in
                guard let self, let window = self.window else { return }
                Task { await self.subscription.purchase(in: window) }
            },
            restore: { [weak self] in
                Task { await self?.subscription.restore() }
            }))
    }
}

private struct PaywallView: View {
    let offer: String
    let buttonTitle: String
    let purchase: () -> Void
    let restore: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 72, height: 72)
            Text("Keep your Dock on your main display").font(.title3.bold())
            Text("ubu stops the Dock jumping to other displays and brings it back if it does.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(offer).font(.headline).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: purchase)
                .keyboardShortcut(.defaultAction).controlSize(.large)
            Text("Payment is charged to your Apple Account. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel it in App Store account settings.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Restore Purchases", action: restore)
                Link("Privacy Policy", destination: Links.privacyPolicy)
                Link("Terms of Use", destination: Links.termsOfUse)
            }
            .buttonStyle(.link).font(.caption)
        }
        .padding(24)
        .frame(width: 400)
    }
}
#endif
