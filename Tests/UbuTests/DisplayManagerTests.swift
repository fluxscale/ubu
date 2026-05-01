import XCTest
@testable import Ubu

final class DisplayManagerTests: XCTestCase {

    func testEdgeZonesForBottomDock() {
        let primary = ScreenInfo(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            isPrimary: true
        )
        let secondary = ScreenInfo(
            displayID: 2,
            frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
            isPrimary: false
        )
        let zones = DisplayManager.edgeZones(
            for: [primary, secondary],
            dockPosition: .bottom,
            edgeThreshold: 2.0
        )
        XCTAssertEqual(zones.count, 1, "Should only have edge zone for non-primary screen")
        let zone = zones[0]
        XCTAssertEqual(zone.displayID, 2)
        XCTAssertEqual(zone.rect.origin.x, 2560)
        XCTAssertEqual(zone.rect.origin.y, 0)
        XCTAssertEqual(zone.rect.size.width, 1920)
        XCTAssertEqual(zone.rect.size.height, 2.0)
    }

    func testEdgeZonesForLeftDock() {
        let primary = ScreenInfo(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            isPrimary: true
        )
        let secondary = ScreenInfo(
            displayID: 2,
            frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
            isPrimary: false
        )
        let zones = DisplayManager.edgeZones(
            for: [primary, secondary],
            dockPosition: .left,
            edgeThreshold: 2.0
        )
        let zone = zones[0]
        XCTAssertEqual(zone.rect.origin.x, 2560)
        XCTAssertEqual(zone.rect.origin.y, 0)
        XCTAssertEqual(zone.rect.size.width, 2.0)
        XCTAssertEqual(zone.rect.size.height, 1080)
    }

    func testEdgeZonesForRightDock() {
        let primary = ScreenInfo(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            isPrimary: true
        )
        let secondary = ScreenInfo(
            displayID: 2,
            frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
            isPrimary: false
        )
        let zones = DisplayManager.edgeZones(
            for: [primary, secondary],
            dockPosition: .right,
            edgeThreshold: 2.0
        )
        let zone = zones[0]
        XCTAssertEqual(zone.rect.origin.x, 2560 + 1920 - 2.0, accuracy: 0.01)
        XCTAssertEqual(zone.rect.size.width, 2.0)
        XCTAssertEqual(zone.rect.size.height, 1080)
    }

    func testNoEdgeZonesForSingleScreen() {
        let primary = ScreenInfo(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            isPrimary: true
        )
        let zones = DisplayManager.edgeZones(
            for: [primary],
            dockPosition: .bottom,
            edgeThreshold: 2.0
        )
        XCTAssertTrue(zones.isEmpty)
    }

    func testThreeScreensProducesTwoEdgeZones() {
        let screens = [
            ScreenInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), isPrimary: true),
            ScreenInfo(displayID: 2, frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080), isPrimary: false),
            ScreenInfo(displayID: 3, frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isPrimary: false),
        ]
        let zones = DisplayManager.edgeZones(for: screens, dockPosition: .bottom, edgeThreshold: 2.0)
        XCTAssertEqual(zones.count, 2)
    }

    func testPointInEdgeZone() {
        let zone = EdgeZone(
            displayID: 2,
            rect: CGRect(x: 2560, y: 0, width: 1920, height: 2.0)
        )
        XCTAssertTrue(zone.contains(point: CGPoint(x: 3000, y: 1.0)))
        XCTAssertFalse(zone.contains(point: CGPoint(x: 3000, y: 5.0)))
        XCTAssertFalse(zone.contains(point: CGPoint(x: 100, y: 1.0)))
    }

    func testDockPositionFromDefaults() {
        XCTAssertEqual(DockPosition.from(orientation: "bottom"), .bottom)
        XCTAssertEqual(DockPosition.from(orientation: "left"), .left)
        XCTAssertEqual(DockPosition.from(orientation: "right"), .right)
        XCTAssertEqual(DockPosition.from(orientation: "unknown"), .bottom)
    }
}
