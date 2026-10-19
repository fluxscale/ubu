import AppKit

/// Two layers: the event tap stops the Dock from moving, and the watcher puts it
/// back on the primary display if it moves anyway.
@MainActor
final class DockMonitor {
    private let displayManager = DisplayManager()
    private let eventTapLayer = EventTapLayer()
    private lazy var watcher = DockWatcher(displayManager: displayManager)

    private(set) var isRunning = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var migrationBlockedCount = 0

    var onStateChanged: (() -> Void)?
    var onFirstMigrationBlocked: (() -> Void)?

    func start() {
        guard !isRunning else { return }

        displayManager.onDisplaysChanged = { [weak self] in
            self?.handleDisplayChange()
        }
        displayManager.start()

        eventTapLayer.onMigrationBlocked = { [weak self] in
            guard let self else { return }
            self.migrationBlockedCount += 1
            if self.migrationBlockedCount == 1 {
                self.onFirstMigrationBlocked?()
            }
        }
        eventTapLayer.updateEdgeZones(displayManager.edgeZones)
        let tapStarted = eventTapLayer.start()

        watcher.onDockOnWrongScreen = { [weak self] in
            self?.moveDockToPrimary()
        }
        watcher.start()

        observeSleepWake()

        isRunning = true
        onStateChanged?()
        Log.monitor.info("DockMonitor started — eventTap=\(tapStarted)")
    }

    func stop() {
        guard isRunning else { return }
        eventTapLayer.stop()
        watcher.stop()
        displayManager.stop()

        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers = []

        isRunning = false
        onStateChanged?()
        Log.monitor.info("DockMonitor stopped")
    }

    private func handleDisplayChange() {
        eventTapLayer.updateEdgeZones(displayManager.edgeZones)
        watcher.triggerBurstPolling()
        Log.monitor.info("Display layout changed — edge zones rebuilt, burst polling active")
    }

    private func moveDockToPrimary() {
        guard let primary = displayManager.primaryScreen else { return }
        DockMover.push(to: primary.frame, dockPosition: displayManager.dockPosition)
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.monitor.info("System going to sleep")
                self?.eventTapLayer.stop()
            }
        })

        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.monitor.info("System woke up")
                self.displayManager.refresh()
                _ = self.eventTapLayer.start()
            }
        })
    }
}
