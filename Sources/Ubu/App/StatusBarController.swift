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
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "ubu — active")
                ?? makeTextIcon("U")
            button.image?.isTemplate = true
            button.appearsDisabled = false
            button.contentTintColor = nil
        case .paused:
            button.image = NSImage(systemSymbolName: "pawprint", accessibilityDescription: "ubu — paused")
                ?? makeTextIcon("U")
            button.image?.isTemplate = true
            button.appearsDisabled = true
            button.contentTintColor = nil
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

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

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

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        UpdateChecker.checkInBackground(silent: false)
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "ubu"
        alert.informativeText = "Keeps your Dock on your primary display.\n\nVersion \(UpdateChecker.currentVersion)\nMIT License"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        onQuit?()
        NSApp.terminate(nil)
    }

    private func makeBeagleIcon(filled: Bool) -> NSImage {
        let s = NSSize(width: 18, height: 18)
        let image = NSImage(size: s, flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Heart-shaped main pad
            let pad = NSBezierPath()
            pad.move(to: NSPoint(x: 9, y: 3))
            pad.curve(to: NSPoint(x: 4, y: 7),
                      controlPoint1: NSPoint(x: 6.5, y: 3),
                      controlPoint2: NSPoint(x: 4, y: 4.5))
            pad.curve(to: NSPoint(x: 9, y: 12),
                      controlPoint1: NSPoint(x: 4, y: 9.5),
                      controlPoint2: NSPoint(x: 6.5, y: 12))
            pad.curve(to: NSPoint(x: 14, y: 7),
                      controlPoint1: NSPoint(x: 11.5, y: 12),
                      controlPoint2: NSPoint(x: 14, y: 9.5))
            pad.curve(to: NSPoint(x: 9, y: 3),
                      controlPoint1: NSPoint(x: 14, y: 4.5),
                      controlPoint2: NSPoint(x: 11.5, y: 3))
            pad.close()

            // Four round toe beans — spaced in arc above pad
            let toe1 = NSBezierPath(ovalIn: NSRect(x: 1.5, y: 12, width: 3, height: 3.5))
            let toe2 = NSBezierPath(ovalIn: NSRect(x: 5, y: 14, width: 2.5, height: 3))
            let toe3 = NSBezierPath(ovalIn: NSRect(x: 10.5, y: 14, width: 2.5, height: 3))
            let toe4 = NSBezierPath(ovalIn: NSRect(x: 13.5, y: 12, width: 3, height: 3.5))

            if filled {
                pad.fill()
                toe1.fill(); toe2.fill(); toe3.fill(); toe4.fill()
            } else {
                pad.lineWidth = 1.3
                pad.stroke()
                for toe in [toe1, toe2, toe3, toe4] {
                    toe.lineWidth = 1.2
                    toe.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func makeTextIcon(_ text: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: text, attributes: attributes)
            str.draw(at: NSPoint(x: 3, y: 1))
            return true
        }
        image.isTemplate = true
        return image
    }
}
