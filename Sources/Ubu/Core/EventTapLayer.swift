import CoreGraphics
import Foundation

final class DwellTracker {
    let thresholdSeconds: TimeInterval
    private var enteredZoneAt: Date?
    private(set) var isSuppressing: Bool = false

    init(thresholdSeconds: TimeInterval) {
        self.thresholdSeconds = thresholdSeconds
    }

    func update(inZone: Bool, at time: Date = Date()) {
        if inZone {
            if enteredZoneAt == nil {
                enteredZoneAt = time
            }
            if let entered = enteredZoneAt, time.timeIntervalSince(entered) >= thresholdSeconds {
                isSuppressing = true
            }
        } else {
            reset()
        }
    }

    func reset() {
        enteredZoneAt = nil
        isSuppressing = false
    }
}

@MainActor
final class EventTapLayer {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let dwellTracker = DwellTracker(thresholdSeconds: 0.1)
    private var edgeZones: [EdgeZone] = []
    private(set) var isRunning = false

    var onMigrationBlocked: (() -> Void)?

    /// Plain moves and drags: dragging a window against an edge moves the Dock too.
    nonisolated static let eventMask: CGEventMask = [
        CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
    ].reduce(0) { $0 | (1 << $1.rawValue) }

    func updateEdgeZones(_ zones: [EdgeZone]) {
        edgeZones = zones
        dwellTracker.reset()
    }

    func start() -> Bool {
        guard !isRunning else { return true }

        // The tap's run loop source lives on the main run loop, so callbacks arrive on the main thread.
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let layer = Unmanaged<EventTapLayer>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { layer.handleEvent(type: type, event: event) }
            }
            // Hand back the event we were given. passRetained here leaked every mouse event.
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.eventTap.error("Failed to create event tap — Accessibility permission likely missing")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isRunning = true
        Log.eventTap.info("Event tap started")
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
        dwellTracker.reset()
        isRunning = false
        Log.eventTap.info("Event tap stopped")
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let location = event.location
        let hitZone = EventTapLayer.zoneContaining(point: location, in: edgeZones)

        dwellTracker.update(inZone: hitZone != nil)

        if dwellTracker.isSuppressing, let zone = hitZone {
            let warpPoint = EventTapLayer.warpTarget(from: location, zone: zone)
            CGWarpMouseCursorPosition(warpPoint)
            event.location = warpPoint
            Log.eventTap.debug("Warped cursor from edge (\(location.x), \(location.y)) → (\(warpPoint.x), \(warpPoint.y))")
            onMigrationBlocked?()
        }
    }

    /// Where to put the cursor so it sits just inside the display, clear of the zone.
    /// The direction comes from the Dock side, so the cursor never leaves the display it is on.
    nonisolated static func warpTarget(from point: CGPoint, zone: EdgeZone) -> CGPoint {
        let pushBack: CGFloat = 6.0
        let r = zone.rect
        switch zone.dockPosition {
        case .bottom: return CGPoint(x: point.x, y: r.minY - pushBack)
        case .left: return CGPoint(x: r.maxX + pushBack, y: point.y)
        case .right: return CGPoint(x: r.minX - pushBack, y: point.y)
        }
    }

    nonisolated static func zoneContaining(point: CGPoint, in zones: [EdgeZone]) -> EdgeZone? {
        zones.first { $0.contains(point: point) }
    }
}
