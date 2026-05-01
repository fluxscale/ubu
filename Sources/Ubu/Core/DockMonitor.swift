import AppKit

struct LayerStatus {
    let name: String
    let isActive: Bool
}

final class DockMonitor {
    private let displayManager = DisplayManager()
    private let eventTapLayer = EventTapLayer()
    private let coreDockBridge = CoreDockBridge()
    private lazy var accessibilityLayer = AccessibilityLayer(displayManager: displayManager)

    private(set) var isRunning = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var migrationBlockedCount = 0

    var onStateChanged: (() -> Void)?
    var onFirstMigrationBlocked: (() -> Void)?

    var layerStatus: [LayerStatus] {
        [
            LayerStatus(name: "EventTap", isActive: eventTapLayer.isRunning),
            LayerStatus(name: "CoreDock", isActive: coreDockBridge.isAvailable),
            LayerStatus(name: "Accessibility", isActive: accessibilityLayer.isRunning),
        ]
    }

    func start() {
        displayManager.start()
        coreDockBridge.load()

        displayManager.onDisplaysChanged = { [weak self] in
            self?.handleDisplayChange()
        }

        eventTapLayer.updateEdgeZones(displayManager.edgeZones)
        let tapStarted = eventTapLayer.start()

        eventTapLayer.onMigrationBlocked = { [weak self] in
            guard let self = self else { return }
            self.migrationBlockedCount += 1
            if self.migrationBlockedCount == 1 {
                self.onFirstMigrationBlocked?()
            }
        }

        accessibilityLayer.onDockOnWrongScreen = { [weak self] currentDisplay, primaryDisplay in
            self?.handleDockMigration(from: currentDisplay, to: primaryDisplay)
        }
        accessibilityLayer.start()

        if tapStarted && coreDockBridge.isAvailable {
            accessibilityLayer.setRelaxedPolling()
        }

        observeSleepWake()

        isRunning = true
        onStateChanged?()

        Log.monitor.info("DockMonitor started — eventTap=\(tapStarted), coreDock=\(self.coreDockBridge.isAvailable)")
    }

    func stop() {
        eventTapLayer.stop()
        accessibilityLayer.stop()
        displayManager.stop()

        if let obs = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        sleepObserver = nil
        wakeObserver = nil

        isRunning = false
        onStateChanged?()
        Log.monitor.info("DockMonitor stopped")
    }

    private func handleDisplayChange() {
        eventTapLayer.updateEdgeZones(displayManager.edgeZones)
        accessibilityLayer.triggerBurstPolling()
        Log.monitor.info("Display config changed — edge zones rebuilt, burst polling active")
    }

    private func handleDockMigration(from currentDisplay: CGDirectDisplayID, to primaryDisplay: CGDirectDisplayID) {
        Log.monitor.info("Dock migration detected: \(currentDisplay) → correcting to \(primaryDisplay)")

        if coreDockBridge.isAvailable {
            let result = coreDockBridge.moveDockToDisplay(displayID: primaryDisplay)
            if case .success = result {
                return
            }
        }

        AccessibilityLayer.forceDockToDisplay(primaryDisplay)
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.monitor.info("System going to sleep")
            self?.eventTapLayer.stop()
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.monitor.info("System woke up")
            self?.displayManager.refreshScreens()
            self?.eventTapLayer.updateEdgeZones(self?.displayManager.edgeZones ?? [])
            _ = self?.eventTapLayer.start()
            self?.accessibilityLayer.triggerBurstPolling()
        }
    }
}
