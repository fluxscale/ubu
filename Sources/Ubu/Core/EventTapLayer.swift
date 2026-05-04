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

final class EventTapLayer {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let dwellTracker = DwellTracker(thresholdSeconds: 0.1)
    private var edgeZones: [EdgeZone] = []
    private(set) var isRunning = false

    var onMigrationBlocked: (() -> Void)?

    func updateEdgeZones(_ zones: [EdgeZone]) {
        edgeZones = zones
        dwellTracker.reset()
    }

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let layer = Unmanaged<EventTapLayer>.fromOpaque(refcon).takeUnretainedValue()
            return layer.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            Log.eventTap.error("Failed to create event tap — Accessibility permission likely missing")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        Log.eventTap.info("Event tap started")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        dwellTracker.reset()
        isRunning = false
        Log.eventTap.info("Event tap stopped")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
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
            return Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }

    static func warpTarget(from point: CGPoint, zone: EdgeZone) -> CGPoint {
        let pushBack: CGFloat = 6.0
        var target = point
        let r = zone.rect
        if r.width > r.height {
            target.y = r.origin.y - pushBack
        } else {
            let zoneMidX = r.origin.x + r.width / 2
            if point.x >= zoneMidX {
                target.x = r.origin.x - pushBack
            } else {
                target.x = r.origin.x + r.width + pushBack
            }
        }
        return target
    }

    static func zoneContaining(point: CGPoint, in zones: [EdgeZone]) -> EdgeZone? {
        zones.first { $0.contains(point: point) }
    }
}
