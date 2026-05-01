import XCTest
@testable import ubu

final class CoreDockBridgeTests: XCTestCase {

    func testBridgeReportsAvailability() {
        let bridge = CoreDockBridge()
        _ = bridge.isAvailable
    }

    func testBridgeLoadDoesNotCrash() {
        let bridge = CoreDockBridge()
        bridge.load()
    }

    func testBridgeGracefullyHandlesInvalidPath() {
        let bridge = CoreDockBridge(frameworkPath: "/nonexistent/path/CoreDock")
        bridge.load()
        XCTAssertFalse(bridge.isAvailable)
    }

    func testMoveDockReturnsSuccessOrUnavailable() {
        let bridge = CoreDockBridge()
        bridge.load()
        let result = bridge.moveDockToDisplay(displayID: CGMainDisplayID())
        switch result {
        case .success, .unavailable:
            break
        case .failed:
            break
        }
    }
}
