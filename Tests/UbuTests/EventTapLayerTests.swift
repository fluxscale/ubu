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
}
