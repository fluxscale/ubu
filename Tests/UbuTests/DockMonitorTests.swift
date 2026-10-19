import XCTest
@testable import ubu

@MainActor
final class DockMonitorTests: XCTestCase {

    func testMonitorStartsAndStops() {
        let monitor = DockMonitor()
        monitor.start()
        XCTAssertTrue(monitor.isRunning)
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testMonitorHandlesMultipleStartStopCycles() {
        let monitor = DockMonitor()
        for _ in 0..<5 {
            monitor.start()
            monitor.start() // second start is a no-op, not a second tap
            monitor.stop()
        }
        XCTAssertFalse(monitor.isRunning)
    }
}
