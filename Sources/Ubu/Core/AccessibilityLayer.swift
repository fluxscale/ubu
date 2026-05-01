import AppKit
import ApplicationServices

final class AccessibilityLayer {
    private var timer: Timer?
    private(set) var isRunning = false
    private var normalInterval: TimeInterval = 2.0
    private var burstInterval: TimeInterval = 0.5
    private var burstDuration: TimeInterval = 10.0
    private var burstEndDate: Date?

    var onDockOnWrongScreen: ((_ currentDisplayID: CGDirectDisplayID, _ primaryDisplayID: CGDirectDisplayID) -> Void)?

    private let displayManager: DisplayManager

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    func start() {
        isRunning = true
        scheduleTimer(interval: normalInterval)
        Log.accessibility.info("Accessibility layer started (interval=\(self.normalInterval)s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        Log.accessibility.info("Accessibility layer stopped")
    }

    func setRelaxedPolling() {
        normalInterval = 5.0
        if burstEndDate == nil {
            scheduleTimer(interval: normalInterval)
        }
        Log.accessibility.info("Switched to relaxed polling (5s)")
    }

    func setNormalPolling() {
        normalInterval = 2.0
        if burstEndDate == nil {
            scheduleTimer(interval: normalInterval)
        }
        Log.accessibility.info("Switched to normal polling (2s)")
    }

    func triggerBurstPolling() {
        burstEndDate = Date().addingTimeInterval(burstDuration)
        scheduleTimer(interval: burstInterval)
        Log.accessibility.info("Burst polling for \(self.burstDuration)s")
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        guard isRunning else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkDockPosition()
        }
    }

    private func checkDockPosition() {
        if let burstEnd = burstEndDate, Date() > burstEnd {
            burstEndDate = nil
            scheduleTimer(interval: normalInterval)
        }

        guard let primaryID = displayManager.primaryDisplayID else { return }

        guard let dockFrame = getDockWindowFrame() else {
            Log.accessibility.debug("Could not read Dock window frame")
            return
        }

        let dockCenter = CGPoint(
            x: dockFrame.midX,
            y: dockFrame.midY
        )

        for screen in displayManager.screens {
            if screen.frame.contains(dockCenter) {
                if screen.displayID != primaryID {
                    Log.accessibility.info("Dock detected on wrong screen (display \(screen.displayID), expected \(primaryID))")
                    onDockOnWrongScreen?(screen.displayID, primaryID)
                }
                return
            }
        }
    }

    private func getDockWindowFrame() -> CGRect? {
        let dockApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        )
        guard let dockApp = dockApps.first else { return nil }

        let axDock = AXUIElementCreateApplication(dockApp.processIdentifier)

        var children: CFTypeRef?
        let childResult = AXUIElementCopyAttributeValue(axDock, kAXChildrenAttribute as CFString, &children)
        guard childResult == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }

        for child in childArray {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)

            var position: CFTypeRef?
            var size: CFTypeRef?
            let posResult = AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &position)
            let sizeResult = AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &size)

            if posResult == .success, sizeResult == .success {
                var point = CGPoint.zero
                var sz = CGSize.zero
                if AXValueGetValue(position as! AXValue, .cgPoint, &point),
                   AXValueGetValue(size as! AXValue, .cgSize, &sz) {
                    return CGRect(origin: point, size: sz)
                }
            }
        }

        return nil
    }

    static func forceDockToDisplay(_ displayID: CGDirectDisplayID) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = [
            "write", "com.apple.dock",
            "last-messagetray-display",
            "-int", "\(displayID)"
        ]
        do {
            try task.run()
            task.waitUntilExit()

            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["Dock"]
            try killTask.run()
            killTask.waitUntilExit()

            Log.accessibility.info("Forced Dock restart to display \(displayID)")
        } catch {
            Log.accessibility.error("Failed to force Dock: \(error.localizedDescription)")
        }
    }
}
