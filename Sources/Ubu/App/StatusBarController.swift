import AppKit

final class StatusBarController {
    enum IconState {
        case active
        case paused
        case warning
    }

    private var statusItem: NSStatusItem?
    private let loginItemManager = LoginItemManager()

    var onPauseToggle: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    private var isPaused = false

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(state: .active)
        buildMenu()
    }

    func updateIcon(state: IconState) {
        guard let button = statusItem?.button else { return }
        switch state {
        case .active:
            button.image = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: "ubu — active")
                ?? makeTextIcon("U")
            button.image?.isTemplate = true
            button.appearsDisabled = false
        case .paused:
            button.image = NSImage(systemSymbolName: "dog", accessibilityDescription: "ubu — paused")
                ?? makeTextIcon("U")
            button.image?.isTemplate = true
            button.appearsDisabled = true
        case .warning:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "ubu — needs permission")
            button.image?.isTemplate = false
            button.contentTintColor = .systemYellow
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "✓ Dock Anchored to Primary Display", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let pauseItem = NSMenuItem(title: "Pause Anchoring", action: #selector(togglePause(_:)), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.tag = 101
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        loginItem.tag = 102
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About ubu", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateStatusText(isPaused: Bool) {
        guard let menu = statusItem?.menu else { return }
        if let item = menu.item(withTag: 100) {
            item.title = isPaused ? "⏸ Anchoring Paused" : "✓ Dock Anchored to Primary Display"
        }
        if let item = menu.item(withTag: 101) {
            item.title = isPaused ? "Resume Anchoring" : "Pause Anchoring"
        }
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        updateStatusText(isPaused: isPaused)
        updateIcon(state: isPaused ? .paused : .active)
        onPauseToggle?(isPaused)
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let newState = !loginItemManager.isEnabled
        loginItemManager.setEnabled(newState)
        sender.state = newState ? .on : .off
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "ubu"
        alert.informativeText = "Keeps your Dock on your primary display.\n\nVersion 1.0.0\nMIT License"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        onQuit?()
        NSApp.terminate(nil)
    }

    private func makeTextIcon(_ text: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: text, attributes: attributes)
        str.draw(at: NSPoint(x: 3, y: 1))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
