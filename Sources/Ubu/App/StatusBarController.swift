import AppKit

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let loginItemManager = LoginItemManager()

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause Anchoring", action: nil, keyEquivalent: "p")
    private let subscribeItem = NSMenuItem(title: "Subscribe…", action: nil, keyEquivalent: "")
    private let restoreItem = NSMenuItem(title: "Restore Purchases", action: nil, keyEquivalent: "")

    var onPauseToggle: (() -> Void)?
    var onGrantPermission: (() -> Void)?
    var onSubscribe: (() -> Void)?
    var onRestore: (() -> Void)?
    var onQuit: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()
        show(.active)
    }

    func show(_ state: AppState) {
        guard let button = statusItem?.button else { return }

        let symbol: String
        switch state {
        case .active: symbol = "pawprint.fill"
        case .paused, .needsSubscription: symbol = "pawprint"
        case .needsPermission: symbol = "exclamationmark.triangle.fill"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ubu") ?? makeTextIcon("U")
        button.image?.isTemplate = state != .needsPermission
        button.contentTintColor = state == .needsPermission ? .systemYellow : nil
        button.appearsDisabled = state == .paused || state == .needsSubscription

        switch state {
        case .active: statusLine.title = "✓ Dock Anchored to Primary Display"
        case .paused: statusLine.title = "⏸ Anchoring Paused"
        case .needsSubscription: statusLine.title = "Subscription Required"
        case .needsPermission: statusLine.title = "Grant Accessibility Access…"
        }
        // Only the permission line does anything when clicked.
        statusLine.action = state == .needsPermission ? #selector(grantPermission) : nil
        statusLine.isEnabled = state == .needsPermission

        pauseItem.title = state == .paused ? "Resume Anchoring" : "Pause Anchoring"
        pauseItem.isEnabled = state == .active || state == .paused

        subscribeItem.isHidden = state != .needsSubscription
        restoreItem.isHidden = state != .needsSubscription
    }

    func setSubscribeTitle(_ title: String) {
        subscribeItem.title = title
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        statusLine.target = self
        menu.addItem(statusLine)
        menu.addItem(.separator())

        #if APP_STORE
        subscribeItem.target = self
        subscribeItem.action = #selector(subscribe)
        menu.addItem(subscribeItem)
        restoreItem.target = self
        restoreItem.action = #selector(restore)
        menu.addItem(restoreItem)
        #endif

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)
        #if !APP_STORE
        // ponytail: the App Sandbox denies launchctl kickstart ("Operation not permitted"), so GitHub edition only.
        menu.addItem(item("Restart Dock", #selector(restartDock)))
        #endif
        menu.addItem(.separator())

        let loginItem = item("Start at Login", #selector(toggleLoginItem(_:)))
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())

        #if APP_STORE
        menu.addItem(item("Manage Subscription…", #selector(manageSubscription)))
        menu.addItem(item("Privacy Policy", #selector(openPrivacyPolicy)))
        menu.addItem(item("Terms of Use", #selector(openTerms)))
        #else
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        #endif
        menu.addItem(item("About ubu", #selector(showAbout)))
        menu.addItem(item("Quit", #selector(quit), key: "q"))

        statusItem?.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func togglePause() { onPauseToggle?() }
    @objc private func grantPermission() { onGrantPermission?() }
    @objc private func subscribe() { onSubscribe?() }
    @objc private func restore() { onRestore?() }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let newState = !loginItemManager.isEnabled
        loginItemManager.setEnabled(newState)
        sender.state = loginItemManager.isEnabled ? .on : .off
    }

    #if !APP_STORE
    @objc private func checkForUpdates() { UpdateChecker.checkInBackground(silent: false) }

    /// Unfreezes a stuck Dock. `-k` makes launchd kill and relaunch it; a plain kill
    /// would leave it dead on macOS 26.
    @objc private func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(getuid())/com.apple.Dock.agent"]
        process.terminationHandler = { process in
            let status = process.terminationStatus
            Log.app.info("Restart Dock: launchctl exited \(status)")
            guard status != 0 else { return }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Couldn't Restart the Dock"
                alert.informativeText = "launchctl exited with status \(status)."
                alert.runModal()
            }
        }
        do {
            try process.run()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
    #endif
    @objc private func manageSubscription() { NSWorkspace.shared.open(Links.manageSubscriptions) }
    @objc private func openPrivacyPolicy() { NSWorkspace.shared.open(Links.privacyPolicy) }
    @objc private func openTerms() { NSWorkspace.shared.open(Links.termsOfUse) }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ubu"
        alert.informativeText = "Keeps your Dock on your primary display.\n\nVersion \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")\nMIT License"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        onQuit?()
        NSApp.terminate(nil)
    }

    private func makeTextIcon(_ text: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.black,
            ]).draw(at: NSPoint(x: 3, y: 1))
            return true
        }
        image.isTemplate = true
        return image
    }
}
