import AppKit
import UserNotifications

@main
struct UbuApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private let dockMonitor = DockMonitor()
    private var permissionTimer: Timer?
    private var hasShownFirstBlockNotification = false

    private var isTrusted = PermissionManager.isTrusted
    private var isPaused = false
    #if APP_STORE
    private let subscription = SubscriptionManager()
    private lazy var paywall = PaywallWindow(subscription: subscription)
    // Locked until StoreKit reports an active subscription.
    private var isSubscribed: Bool { subscription.isSubscribed }
    #else
    private let isSubscribed = true
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("ubu starting up")

        let survivors = SingleInstance.takeOver()
        guard survivors.isEmpty else {
            SingleInstance.explain(survivors)
            NSApp.terminate(nil)
            return
        }
        SingleInstance.quitWhenReplaced { [weak self] in
            self?.dockMonitor.stop()
            NSApp.terminate(nil)
        }

        statusBar.setup()
        statusBar.onPauseToggle = { [weak self] in
            guard let self else { return }
            self.isPaused.toggle()
            self.apply()
        }
        statusBar.onGrantPermission = { PermissionManager.openAccessibilitySettings() }
        statusBar.onQuit = { [weak self] in
            self?.dockMonitor.stop()
            Log.app.info("ubu shutting down")
        }

        dockMonitor.onFirstMigrationBlocked = { [weak self] in
            guard let self, !self.hasShownFirstBlockNotification else { return }
            self.hasShownFirstBlockNotification = true
            self.sendNotification(title: "ubu", body: "ubu is keeping your Dock on your primary display.")
        }

        if !isTrusted {
            PermissionManager.requestAccessibility()
            permissionTimer = PermissionManager.waitForAccessibility { [weak self] in
                self?.permissionTimer = nil
                self?.isTrusted = true
                self?.apply()
            }
        }

        #if APP_STORE
        // App Review: no launch at login without the user opting in, and no self-updating.
        statusBar.onSubscribe = { [weak self] in
            self?.paywall.show()
        }
        statusBar.onRestore = { [weak self] in
            Task { await self?.subscription.restore() }
        }
        subscription.onChange = { [weak self] in
            guard let self else { return }
            self.statusBar.setSubscribeTitle(self.subscription.purchaseTitle)
            if self.subscription.isSubscribed {
                self.paywall.close()
            } else {
                self.paywall.refresh()
            }
            self.apply()
        }
        subscription.start()
        #else
        LoginItemManager().registerOnFirstLaunch()
        UpdateChecker.checkInBackground(silent: true)
        #endif

        apply()
    }

    /// Brings the monitor and the menu in line with the current state.
    private func apply() {
        let state = AppState.resolve(trusted: isTrusted, subscribed: isSubscribed, paused: isPaused)
        if state.isMonitoring {
            dockMonitor.start()
        } else {
            dockMonitor.stop()
        }
        statusBar.show(state)
        Log.app.info("State: \(String(describing: state))")
    }

    private func sendNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else {
            Log.app.info("Skipping notification (no bundle context): \(body)")
            return
        }
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try? await center.add(UNNotificationRequest(identifier: "ubu.first-block", content: content, trigger: nil))
        }
    }
}
