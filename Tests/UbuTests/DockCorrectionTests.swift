import XCTest
@testable import ubu

final class DockCorrectionTests: XCTestCase {

    // MARK: DockLocator

    private let screens = [
        ScreenInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 2056, height: 1329), isPrimary: true),
        ScreenInfo(displayID: 3, frame: CGRect(x: -1920, y: 141, width: 1920, height: 1080), isPrimary: false),
    ]

    func testLocatorMapsDockWindowToItsDisplay() {
        // Bounds observed on macOS 26: the Dock-level window spans the Dock's display.
        XCTAssertEqual(DockLocator.display(containing: CGRect(x: 0, y: 0, width: 2056, height: 1329), in: screens), 1)
        XCTAssertEqual(DockLocator.display(containing: CGRect(x: -1920, y: 141, width: 1920, height: 1080), in: screens), 3)
        XCTAssertNil(DockLocator.display(containing: CGRect(x: 9000, y: 0, width: 10, height: 10), in: screens))
    }

    // MARK: DockMover

    func testBottomPushApproachesAndEndsInsideBottomEdge() {
        let frame = CGRect(x: 0, y: 0, width: 2056, height: 1329)
        let path = DockMover.pushPath(on: frame, dockPosition: .bottom)
        XCTAssertEqual(path.count, 8)
        XCTAssertEqual(path.first, CGPoint(x: 1028, y: 1279))
        XCTAssertEqual(path.last, CGPoint(x: 1028, y: 1328))
        XCTAssertTrue(path.allSatisfy(frame.contains), "the push must stay on the target display")
        XCTAssertEqual(path, path.sorted { $0.y < $1.y }, "moves steadily toward the edge")
    }

    func testSidePushesEndAtTheirEdges() {
        let frame = CGRect(x: -1920, y: 141, width: 1920, height: 1080)
        XCTAssertEqual(DockMover.pushPath(on: frame, dockPosition: .left).last, CGPoint(x: -1919, y: 681))
        XCTAssertEqual(DockMover.pushPath(on: frame, dockPosition: .right).last, CGPoint(x: -1, y: 681))
    }

    func testPressurePointsIntoDockEdge() {
        XCTAssertEqual(DockMover.pressure(for: .bottom).dy, 5)
        XCTAssertEqual(DockMover.pressure(for: .left).dx, -5)
        XCTAssertEqual(DockMover.pressure(for: .right).dx, 5)
    }

    // MARK: CorrectionThrottle

    func testThrottleSpacesAttempts() {
        var throttle = CorrectionThrottle()
        let t0 = Date()
        XCTAssertTrue(throttle.allow(at: t0))
        XCTAssertFalse(throttle.allow(at: t0.addingTimeInterval(1)), "too soon")
        XCTAssertTrue(throttle.allow(at: t0.addingTimeInterval(3)))
    }

    func testThrottleGivesUpAfterMaxAttemptsUntilReset() {
        var throttle = CorrectionThrottle()
        let t0 = Date()
        for i in 0..<3 { XCTAssertTrue(throttle.allow(at: t0.addingTimeInterval(Double(i) * 10))) }
        XCTAssertFalse(throttle.allow(at: t0.addingTimeInterval(100)), "a correction that never works must stop")
        throttle.reset()
        XCTAssertTrue(throttle.allow(at: t0.addingTimeInterval(101)))
    }
}
