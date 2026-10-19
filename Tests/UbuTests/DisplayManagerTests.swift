import XCTest
@testable import ubu

// CG coordinates: origin top-left of primary, Y increases downward
final class DisplayManagerTests: XCTestCase {

    private func screen(_ id: CGDirectDisplayID, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                        primary: Bool = false) -> ScreenInfo {
        ScreenInfo(displayID: id, frame: CGRect(x: x, y: y, width: w, height: h), isPrimary: primary)
    }

    func testBottomDockZoneCoversExposedBottomEdge() {
        let screens = [screen(1, 0, 0, 2560, 1440, primary: true), screen(2, 2560, 360, 1920, 1080)]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .bottom, edgeThreshold: 4)
        XCTAssertEqual(zones, [EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 1436, width: 1920, height: 4),
                                        dockPosition: .bottom)])
    }

    func testLeftDockZoneOnRightEdgeOfOuterDisplay() {
        // Secondary sits LEFT of primary, so its left edge is exposed.
        let screens = [screen(1, 0, 0, 2560, 1440, primary: true), screen(2, -1920, 0, 1920, 1080)]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .left, edgeThreshold: 4)
        XCTAssertEqual(zones, [EdgeZone(displayID: 2, rect: CGRect(x: -1920, y: 0, width: 4, height: 1080),
                                        dockPosition: .left)])
    }

    func testRightDockZoneOnExposedRightEdge() {
        let screens = [screen(1, 0, 0, 2560, 1440, primary: true), screen(2, 2560, 0, 1920, 1080)]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .right, edgeThreshold: 4)
        XCTAssertEqual(zones, [EdgeZone(displayID: 2, rect: CGRect(x: 4476, y: 0, width: 4, height: 1080),
                                        dockPosition: .right)])
    }

    func testLeftDockEdgeFullySharedWithPrimaryGetsNoZone() {
        // Secondary RIGHT of primary, same height: its left edge is the doorway back to primary.
        let screens = [screen(1, 0, 0, 2560, 1440, primary: true), screen(2, 2560, 0, 1920, 1440)]
        XCTAssertTrue(DisplayManager.edgeZones(for: screens, dockPosition: .left, edgeThreshold: 8).isEmpty)
    }

    func testMonitorStackedAboveLaptopOnlyGuardsOverhang() {
        // 2560-wide monitor above a 1512-wide laptop: only the overhang either side is a real edge.
        let screens = [screen(1, 0, 0, 1512, 982, primary: true), screen(2, -524, -1440, 2560, 1440)]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .bottom, edgeThreshold: 8)
        XCTAssertEqual(zones.map(\.rect), [
            CGRect(x: -524, y: -8, width: 524, height: 8),
            CGRect(x: 1512, y: -8, width: 524, height: 8),
        ])
    }

    func testThisMachinesLayoutWithLeftDock() {
        // Real layout from the dev Mac: 4K right of the laptop, raised; 1080p on the left.
        let screens = [
            screen(1, 0, 0, 2056, 1329, primary: true),
            screen(2, 2056, -860, 3840, 2160),
            screen(3, -1920, 141, 1920, 1080),
        ]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .left, edgeThreshold: 8)
        // The 4K's left edge touches the laptop between y=0 and y=1300: only the part above stays guarded.
        XCTAssertEqual(zones.first { $0.displayID == 2 }?.rect, CGRect(x: 2056, y: -860, width: 8, height: 860))
        XCTAssertEqual(zones.first { $0.displayID == 3 }?.rect, CGRect(x: -1920, y: 141, width: 8, height: 1080))
    }

    func testNoEdgeZonesForSingleScreen() {
        let zones = DisplayManager.edgeZones(for: [screen(1, 0, 0, 2560, 1440, primary: true)],
                                             dockPosition: .bottom, edgeThreshold: 4)
        XCTAssertTrue(zones.isEmpty)
    }

    func testSubtractSplitsAndDropsSlivers() {
        XCTAssertEqual(DisplayManager.subtract([40...60], from: 0...100), [0...40, 60...100])
        XCTAssertEqual(DisplayManager.subtract([0...100], from: 0...100), [])
        XCTAssertEqual(DisplayManager.subtract([200...300], from: 0...100), [0...100])
        XCTAssertEqual(DisplayManager.subtract([0.5...100], from: 0...100), [], "half-point sliver is dropped")
    }

    func testPointInBottomEdgeZone() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 1076, width: 1920, height: 4), dockPosition: .bottom)
        XCTAssertTrue(zone.contains(point: CGPoint(x: 3000, y: 1077)))
        XCTAssertFalse(zone.contains(point: CGPoint(x: 3000, y: 500)))
        XCTAssertFalse(zone.contains(point: CGPoint(x: 100, y: 1077)))
    }

    func testDockPositionFromDefaults() {
        XCTAssertEqual(DockPosition.from(orientation: "bottom"), .bottom)
        XCTAssertEqual(DockPosition.from(orientation: "left"), .left)
        XCTAssertEqual(DockPosition.from(orientation: "right"), .right)
        XCTAssertEqual(DockPosition.from(orientation: "unknown"), .bottom)
    }

    func testDockPositionInferredFromVisibleFrame() {
        // AppKit coordinates (y up). Insets measured on the dev Mac: Dock 60pt, menu bar 39pt.
        let frame = CGRect(x: 0, y: 0, width: 2056, height: 1329)
        XCTAssertEqual(DockPosition.inferred(frame: frame, visibleFrame: CGRect(x: 0, y: 60, width: 2056, height: 1230)), .bottom)
        XCTAssertEqual(DockPosition.inferred(frame: frame, visibleFrame: CGRect(x: 70, y: 0, width: 1986, height: 1290)), .left)
        XCTAssertEqual(DockPosition.inferred(frame: frame, visibleFrame: CGRect(x: 0, y: 0, width: 1986, height: 1290)), .right)
        XCTAssertNil(DockPosition.inferred(frame: frame, visibleFrame: CGRect(x: 0, y: 0, width: 2056, height: 1290)),
                     "menu bar alone says nothing about the Dock")
    }
}
