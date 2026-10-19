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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("ubu starting up")

        statusBar.setup()

        statusBar.onPauseToggle = { [weak self] paused in
            if paused {
                self?.dockMonitor.stop()
                Log.app.info("Monitoring paused by user")
            } else {
                self?.startMonitoring()
            }
        }

        statusBar.onQuit = { [weak self] in
            self?.dockMonitor.stop()
            Log.app.info("ubu shutting down")
        }

        if PermissionManager.isTrusted {
            startMonitoring()
        } else {
            statusBar.updateIcon(state: .warning)
            PermissionManager.requestAccessibility()
            permissionTimer = PermissionManager.waitForAccessibility { [weak self] in
                self?.permissionTimer = nil
                self?.startMonitoring()
            }
        }

        LoginItemManager().registerOnFirstLaunch()

        UpdateChecker.checkInBackground(silent: true)
    }

    private func startMonitoring() {
        dockMonitor.onStateChanged = { [weak self] in
            guard let self else { return }
            self.statusBar.updateIcon(state: self.dockMonitor.isRunning ? .active : .paused)
        }

        dockMonitor.onFirstMigrationBlocked = { [weak self] in
            guard let self, !self.hasShownFirstBlockNotification else { return }
            self.hasShownFirstBlockNotification = true
            self.sendNotification(
                title: "ubu",
                body: "ubu is keeping your Dock on your primary display."
            )
        }

        dockMonitor.start()
        statusBar.updateIcon(state: .active)
        Log.app.info("Monitoring started")
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
