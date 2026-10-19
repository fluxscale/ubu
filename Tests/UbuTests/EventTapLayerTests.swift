import XCTest
@testable import ubu

final class EventTapLayerTests: XCTestCase {

    func testDwellTrackerStartsInactive() {
        let tracker = DwellTracker(thresholdSeconds: 0.3)
        XCTAssertFalse(tracker.isSuppressing)
    }

    func testDwellTrackerActivatesAfterThreshold() {
        let tracker = DwellTracker(thresholdSeconds: 0.3)
        let start = Date()
        tracker.update(inZone: true, at: start)
        XCTAssertFalse(tracker.isSuppressing)
        tracker.update(inZone: true, at: start.addingTimeInterval(0.31))
        XCTAssertTrue(tracker.isSuppressing)
    }

    func testDwellTrackerResetsWhenLeavingZone() {
        let tracker = DwellTracker(thresholdSeconds: 0.3)
        let start = Date()
        tracker.update(inZone: true, at: start)
        tracker.update(inZone: true, at: start.addingTimeInterval(0.31))
        XCTAssertTrue(tracker.isSuppressing)
        tracker.update(inZone: false, at: start.addingTimeInterval(0.5))
        XCTAssertFalse(tracker.isSuppressing)
    }

    func testDwellTrackerDoesNotActivateBeforeThreshold() {
        let tracker = DwellTracker(thresholdSeconds: 0.3)
        let start = Date()
        tracker.update(inZone: true, at: start)
        tracker.update(inZone: true, at: start.addingTimeInterval(0.2))
        XCTAssertFalse(tracker.isSuppressing)
    }

    func testDwellTrackerReactivatesAfterReset() {
        let tracker = DwellTracker(thresholdSeconds: 0.3)
        let start = Date()
        tracker.update(inZone: true, at: start)
        tracker.update(inZone: true, at: start.addingTimeInterval(0.31))
        XCTAssertTrue(tracker.isSuppressing)
        tracker.update(inZone: false, at: start.addingTimeInterval(0.5))
        let restart = start.addingTimeInterval(1.0)
        tracker.update(inZone: true, at: restart)
        XCTAssertFalse(tracker.isSuppressing)
        tracker.update(inZone: true, at: restart.addingTimeInterval(0.31))
        XCTAssertTrue(tracker.isSuppressing)
    }

    func testPointHitsEdgeZone() {
        let zones = [EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 0, width: 1920, height: 2), dockPosition: .bottom)]
        XCTAssertEqual(EventTapLayer.zoneContaining(point: CGPoint(x: 3000, y: 1), in: zones)?.displayID, 2)
    }

    func testPointMissesAllZones() {
        let zones = [EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 0, width: 1920, height: 2), dockPosition: .bottom)]
        XCTAssertNil(EventTapLayer.zoneContaining(point: CGPoint(x: 3000, y: 100), in: zones))
    }

    func testWarpTargetBottomEdge() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 1072, width: 1920, height: 8), dockPosition: .bottom)
        XCTAssertEqual(EventTapLayer.warpTarget(from: CGPoint(x: 3000, y: 1075), zone: zone), CGPoint(x: 3000, y: 1066))
    }

    func testWarpTargetLeftDockPushesRightWhereverCursorIsInBand() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: -1920, y: 0, width: 8, height: 1080), dockPosition: .left)
        for x: CGFloat in [-1920, -1917, -1913] {
            XCTAssertEqual(EventTapLayer.warpTarget(from: CGPoint(x: x, y: 500), zone: zone), CGPoint(x: -1906, y: 500))
        }
    }

    func testWarpTargetRightDockNeverLeavesDisplay() {
        // Display spans x 2560..4480. Old midpoint logic sent the left half of the band to x=4486.
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 4472, y: 0, width: 8, height: 1080), dockPosition: .right)
        for x: CGFloat in [4472, 4474, 4479] {
            let target = EventTapLayer.warpTarget(from: CGPoint(x: x, y: 500), zone: zone)
            XCTAssertEqual(target, CGPoint(x: 4466, y: 500))
            XCTAssertLessThan(target.x, 4480)
        }
    }

    func testEventMaskIncludesMovesAndDrags() {
        for type in [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
            XCTAssertNotEqual(EventTapLayer.eventMask & (1 << type.rawValue), 0, "\(type)")
        }
        XCTAssertEqual(EventTapLayer.eventMask & (1 << CGEventType.leftMouseDown.rawValue), 0)
    }
}
