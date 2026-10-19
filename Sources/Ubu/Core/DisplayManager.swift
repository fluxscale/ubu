import AppKit

enum DockPosition: String, Sendable {
    case bottom, left, right

    static func from(orientation: String) -> DockPosition {
        switch orientation.lowercased() {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    /// Infers the Dock side from how far it pushes in a screen's visible frame (AppKit coordinates).
    /// Needs no access to the Dock's preferences, which the App Sandbox blocks.
    static func inferred(frame: CGRect, visibleFrame: CGRect) -> DockPosition? {
        let insets: [(DockPosition, CGFloat)] = [
            (.bottom, visibleFrame.minY - frame.minY),
            (.left, visibleFrame.minX - frame.minX),
            (.right, frame.maxX - visibleFrame.maxX),
        ]
        guard let widest = insets.max(by: { $0.1 < $1.1 }), widest.1 > 0 else { return nil }
        return widest.0
    }

    @MainActor
    static func current() -> DockPosition {
        if let orientation = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") {
            return from(orientation: orientation)
        }
        for screen in NSScreen.screens {
            if let position = inferred(frame: screen.frame, visibleFrame: screen.visibleFrame) {
                return position
            }
        }
        return .bottom
    }
}

struct ScreenInfo: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let isPrimary: Bool
}

struct EdgeZone: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let rect: CGRect
    let dockPosition: DockPosition

    func contains(point: CGPoint) -> Bool {
        rect.contains(point)
    }
}

@MainActor
final class DisplayManager {
    private(set) var screens: [ScreenInfo] = []
    private(set) var edgeZones: [EdgeZone] = []
    private(set) var dockPosition: DockPosition = .bottom

    var primaryScreen: ScreenInfo? {
        screens.first(where: \.isPrimary)
    }

    var onDisplaysChanged: (() -> Void)?

    private var notificationObserver: NSObjectProtocol?

    func start() {
        refreshScreens()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }

    /// Re-reads the display layout and tells the owner to rebuild anything derived from it.
    func refresh() {
        refreshScreens()
        onDisplaysChanged?()
    }

    func refreshScreens() {
        let mainID = CGMainDisplayID()
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, &activeDisplays, &displayCount)

        screens = activeDisplays.prefix(Int(displayCount)).map { id in
            ScreenInfo(displayID: id, frame: CGDisplayBounds(id), isPrimary: id == mainID)
        }
        dockPosition = DockPosition.current()
        edgeZones = DisplayManager.edgeZones(for: screens, dockPosition: dockPosition, edgeThreshold: 8.0)
        Log.display.info("Refreshed screens: \(self.screens.count) displays, primary=\(mainID), dock=\(self.dockPosition.rawValue), zones=\(self.edgeZones.count)")
    }

    /// Zones along the Dock edge of every secondary display (CG coordinates, y down).
    /// Stretches of that edge where another display continues are left out: the cursor
    /// crosses there instead of pressing against an edge, so macOS never moves the Dock.
    nonisolated static func edgeZones(
        for screens: [ScreenInfo],
        dockPosition: DockPosition,
        edgeThreshold: CGFloat
    ) -> [EdgeZone] {
        screens.filter { !$0.isPrimary }.flatMap { screen -> [EdgeZone] in
            let f = screen.frame
            let edge: ClosedRange<CGFloat>
            let neighbours: [ClosedRange<CGFloat>]
            switch dockPosition {
            case .bottom:
                edge = f.minX...f.maxX
                neighbours = screens.filter { abs($0.frame.minY - f.maxY) < 1 }.map { $0.frame.minX...$0.frame.maxX }
            case .left:
                edge = f.minY...f.maxY
                neighbours = screens.filter { abs($0.frame.maxX - f.minX) < 1 }.map { $0.frame.minY...$0.frame.maxY }
            case .right:
                edge = f.minY...f.maxY
                neighbours = screens.filter { abs($0.frame.minX - f.maxX) < 1 }.map { $0.frame.minY...$0.frame.maxY }
            }

            return subtract(neighbours, from: edge).map { span in
                let length = span.upperBound - span.lowerBound
                let rect: CGRect
                switch dockPosition {
                case .bottom:
                    rect = CGRect(x: span.lowerBound, y: f.maxY - edgeThreshold, width: length, height: edgeThreshold)
                case .left:
                    rect = CGRect(x: f.minX, y: span.lowerBound, width: edgeThreshold, height: length)
                case .right:
                    rect = CGRect(x: f.maxX - edgeThreshold, y: span.lowerBound, width: edgeThreshold, height: length)
                }
                return EdgeZone(displayID: screen.displayID, rect: rect, dockPosition: dockPosition)
            }
        }
    }

    /// Removes `cuts` from `span`, dropping leftover slivers under a point long.
    nonisolated static func subtract(
        _ cuts: [ClosedRange<CGFloat>],
        from span: ClosedRange<CGFloat>
    ) -> [ClosedRange<CGFloat>] {
        var pieces = [span]
        for cut in cuts {
            pieces = pieces.flatMap { piece -> [ClosedRange<CGFloat>] in
                guard cut.overlaps(piece) else { return [piece] }
                var remaining: [ClosedRange<CGFloat>] = []
                if cut.lowerBound > piece.lowerBound { remaining.append(piece.lowerBound...cut.lowerBound) }
                if cut.upperBound < piece.upperBound { remaining.append(cut.upperBound...piece.upperBound) }
                return remaining
            }
        }
        return pieces.filter { $0.upperBound - $0.lowerBound >= 1 }
    }
}
