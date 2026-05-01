import AppKit

enum DockPosition: String {
    case bottom, left, right

    static func from(orientation: String) -> DockPosition {
        switch orientation.lowercased() {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    static func current() -> DockPosition {
        guard let plist = UserDefaults(suiteName: "com.apple.dock"),
              let orientation = plist.string(forKey: "orientation") else {
            return .bottom
        }
        return .from(orientation: orientation)
    }
}

struct ScreenInfo: Equatable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let isPrimary: Bool
}

struct EdgeZone: Equatable {
    let displayID: CGDirectDisplayID
    let rect: CGRect

    func contains(point: CGPoint) -> Bool {
        rect.contains(point)
    }
}

final class DisplayManager {
    private(set) var screens: [ScreenInfo] = []
    private(set) var edgeZones: [EdgeZone] = []
    private(set) var dockPosition: DockPosition = .bottom

    var primaryDisplayID: CGDirectDisplayID? {
        screens.first(where: { $0.isPrimary })?.displayID
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
            self?.refreshScreens()
            self?.onDisplaysChanged?()
        }
    }

    func stop() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }

    func refreshScreens() {
        screens = NSScreen.screens.enumerated().map { index, screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGDirectDisplayID(index)
            return ScreenInfo(
                displayID: displayID,
                frame: screen.frame,
                isPrimary: index == 0
            )
        }
        dockPosition = DockPosition.current()
        edgeZones = DisplayManager.edgeZones(
            for: screens,
            dockPosition: dockPosition,
            edgeThreshold: 2.0
        )
        Log.display.info("Refreshed screens: \(self.screens.count) displays, dock=\(self.dockPosition.rawValue), zones=\(self.edgeZones.count)")
    }

    static func edgeZones(
        for screens: [ScreenInfo],
        dockPosition: DockPosition,
        edgeThreshold: CGFloat
    ) -> [EdgeZone] {
        screens
            .filter { !$0.isPrimary }
            .map { screen in
                let rect: CGRect
                switch dockPosition {
                case .bottom:
                    rect = CGRect(
                        x: screen.frame.origin.x,
                        y: screen.frame.origin.y,
                        width: screen.frame.width,
                        height: edgeThreshold
                    )
                case .left:
                    rect = CGRect(
                        x: screen.frame.origin.x,
                        y: screen.frame.origin.y,
                        width: edgeThreshold,
                        height: screen.frame.height
                    )
                case .right:
                    rect = CGRect(
                        x: screen.frame.origin.x + screen.frame.width - edgeThreshold,
                        y: screen.frame.origin.y,
                        width: edgeThreshold,
                        height: screen.frame.height
                    )
                }
                return EdgeZone(displayID: screen.displayID, rect: rect)
            }
    }
}
