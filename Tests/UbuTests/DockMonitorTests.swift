import XCTest
@testable import ubu

final class DockMonitorTests: XCTestCase {

    func testMonitorStartsAllLayers() {
        let monitor = DockMonitor()
        monitor.start()
        XCTAssertTrue(monitor.isRunning)
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testMonitorReportsLayerStatus() {
        let monitor = DockMonitor()
        let status = monitor.layerStatus
        XCTAssertEqual(status.count, 3)
        XCTAssertEqual(status[0].name, "EventTap")
        XCTAssertEqual(status[1].name, "CoreDock")
        XCTAssertEqual(status[2].name, "Accessibility")
    }

    func testMonitorHandlesMultipleStartStopCycles() {
        let monitor = DockMonitor()
        for _ in 0..<5 {
            monitor.start()
            monitor.stop()
        }
        XCTAssertFalse(monitor.isRunning)
    }
}
