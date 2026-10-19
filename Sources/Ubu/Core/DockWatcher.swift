import AppKit

/// Caps automatic corrections so one that can't succeed never becomes a loop
/// that keeps grabbing the cursor.
struct CorrectionThrottle {
    var minInterval: TimeInterval = 3
    var maxAttempts = 3
    private(set) var attempts = 0
    private var lastAttempt: Date?

    mutating func allow(at now: Date) -> Bool {
        guard attempts < maxAttempts else { return false }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < minInterval { return false }
        attempts += 1
        lastAttempt = now
        return true
    }

    mutating func reset() {
        attempts = 0
        lastAttempt = nil
    }
}

/// Safety net: polls where the Dock is and asks for a correction when it has
/// landed on a secondary display anyway (fast flicks, sleep/wake, display changes).
@MainActor
final class DockWatcher {
    private var timer: Timer?
    private(set) var isRunning = false
    private let normalInterval: TimeInterval = 2.0
    private let burstInterval: TimeInterval = 0.5
    private let burstDuration: TimeInterval = 10.0
    private var burstEndDate: Date?
    private var throttle = CorrectionThrottle()

    var onDockOnWrongScreen: (() -> Void)?

    private let displayManager: DisplayManager

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    func start() {
        isRunning = true
        scheduleTimer(interval: normalInterval)
        Log.watcher.info("Dock watcher started (interval=\(self.normalInterval)s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        Log.watcher.info("Dock watcher stopped")
    }

    /// Polls faster for a while after the layout changes, and allows fresh correction attempts.
    func triggerBurstPolling() {
        throttle.reset()
        burstEndDate = Date().addingTimeInterval(burstDuration)
        scheduleTimer(interval: burstInterval)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        guard isRunning else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        if let burstEnd = burstEndDate, Date() > burstEnd {
            burstEndDate = nil
            scheduleTimer(interval: normalInterval)
        }

        // Dock moved to another side: edge zones are stale until rebuilt.
        if DockPosition.current() != displayManager.dockPosition {
            displayManager.refresh()
        }

        guard let primary = displayManager.primaryScreen,
              let dockBounds = DockLocator.dockWindowBounds(),
              let dockDisplay = DockLocator.display(containing: dockBounds, in: displayManager.screens)
        else { return }

        if dockDisplay == primary.displayID {
            throttle.reset()
            return
        }

        // Never grab the pointer in the middle of a drag.
        guard NSEvent.pressedMouseButtons == 0, throttle.allow(at: Date()) else { return }

        Log.watcher.info("Dock on display \(dockDisplay), expected \(primary.displayID) — correcting (attempt \(self.throttle.attempts))")
        onDockOnWrongScreen?()
    }
}
