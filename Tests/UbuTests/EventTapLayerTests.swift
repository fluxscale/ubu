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
        let zones = [
            EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 0, width: 1920, height: 2.0))
        ]
        let result = EventTapLayer.zoneContaining(point: CGPoint(x: 3000, y: 1.0), in: zones)
        XCTAssertEqual(result?.displayID, 2)
    }

    func testPointMissesAllZones() {
        let zones = [
            EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 0, width: 1920, height: 2.0))
        ]
        let result = EventTapLayer.zoneContaining(point: CGPoint(x: 3000, y: 100.0), in: zones)
        XCTAssertNil(result)
    }

    func testWarpTargetBottomEdge() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 1072, width: 1920, height: 8))
        let point = CGPoint(x: 3000, y: 1075)
        let target = EventTapLayer.warpTarget(from: point, zone: zone)
        XCTAssertEqual(target.x, 3000, accuracy: 0.01)
        XCTAssertEqual(target.y, 1072 - 6.0, accuracy: 0.01)
    }

    func testWarpTargetLeftEdge() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 2560, y: 0, width: 8, height: 1080))
        let point = CGPoint(x: 2562, y: 500)
        let target = EventTapLayer.warpTarget(from: point, zone: zone)
        XCTAssertEqual(target.x, 2560 + 8 + 6.0, accuracy: 0.01)
        XCTAssertEqual(target.y, 500, accuracy: 0.01)
    }

    func testWarpTargetRightEdge() {
        let zone = EdgeZone(displayID: 2, rect: CGRect(x: 4472, y: 0, width: 8, height: 1080))
        let point = CGPoint(x: 4477, y: 500)
        let target = EventTapLayer.warpTarget(from: point, zone: zone)
        XCTAssertEqual(target.x, 4472 - 6.0, accuracy: 0.01)
        XCTAssertEqual(target.y, 500, accuracy: 0.01)
    }
}
