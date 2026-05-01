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
            button.image = makeBeagleIcon(filled: true)
            button.image?.accessibilityDescription = "ubu — active"
            button.appearsDisabled = false
            button.contentTintColor = nil
        case .paused:
            button.image = makeBeagleIcon(filled: false)
            button.image?.accessibilityDescription = "ubu — paused"
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

    private func makeBeagleIcon(filled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()

            // Beagle profile facing right — drawn in 18x18 canvas
            // Body
            path.move(to: NSPoint(x: 3, y: 4))
            path.curve(to: NSPoint(x: 5, y: 2.5),
                       controlPoint1: NSPoint(x: 3, y: 3),
                       controlPoint2: NSPoint(x: 4, y: 2.5))
            // Belly to rear legs
            path.curve(to: NSPoint(x: 12, y: 2.5),
                       controlPoint1: NSPoint(x: 7, y: 2),
                       controlPoint2: NSPoint(x: 10, y: 2))
            // Rear leg
            path.line(to: NSPoint(x: 12, y: 1))
            path.line(to: NSPoint(x: 13.5, y: 1))
            path.line(to: NSPoint(x: 13.5, y: 3))
            // Tail (up, slight curve — beagle characteristic)
            path.curve(to: NSPoint(x: 15, y: 8),
                       controlPoint1: NSPoint(x: 14.5, y: 4),
                       controlPoint2: NSPoint(x: 15, y: 6))
            path.curve(to: NSPoint(x: 14.5, y: 10),
                       controlPoint1: NSPoint(x: 15, y: 9),
                       controlPoint2: NSPoint(x: 14.8, y: 9.5))
            // Back
            path.curve(to: NSPoint(x: 10, y: 12),
                       controlPoint1: NSPoint(x: 13.5, y: 11),
                       controlPoint2: NSPoint(x: 12, y: 12))
            // Head (rounder, beagle-like)
            path.curve(to: NSPoint(x: 6, y: 14),
                       controlPoint1: NSPoint(x: 8.5, y: 12.5),
                       controlPoint2: NSPoint(x: 7, y: 14))
            // Muzzle (longer, square — beagle trait)
            path.curve(to: NSPoint(x: 2, y: 12),
                       controlPoint1: NSPoint(x: 4.5, y: 14),
                       controlPoint2: NSPoint(x: 2.5, y: 13.5))
            path.line(to: NSPoint(x: 1.5, y: 11))
            // Floppy ear (signature beagle feature — hangs down)
            path.curve(to: NSPoint(x: 2, y: 7),
                       controlPoint1: NSPoint(x: 0.5, y: 10),
                       controlPoint2: NSPoint(x: 0.5, y: 8))
            path.curve(to: NSPoint(x: 4, y: 6),
                       controlPoint1: NSPoint(x: 2.5, y: 6.5),
                       controlPoint2: NSPoint(x: 3, y: 6))
            // Front chest down to front leg
            path.curve(to: NSPoint(x: 5, y: 3.5),
                       controlPoint1: NSPoint(x: 4.5, y: 5),
                       controlPoint2: NSPoint(x: 5, y: 4))
            // Front leg
            path.line(to: NSPoint(x: 5, y: 1))
            path.line(to: NSPoint(x: 6.5, y: 1))
            path.line(to: NSPoint(x: 6.5, y: 3))
            path.curve(to: NSPoint(x: 3, y: 4),
                       controlPoint1: NSPoint(x: 5.5, y: 3),
                       controlPoint2: NSPoint(x: 4, y: 3.5))
            path.close()

            NSColor.black.setFill()
            NSColor.black.setStroke()
            if filled {
                path.fill()
            } else {
                path.lineWidth = 1.2
                path.stroke()
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
