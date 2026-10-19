import XCTest
@testable import ubu

final class AppStateTests: XCTestCase {

    func testPermissionComesFirst() {
        XCTAssertEqual(AppState.resolve(trusted: false, subscribed: false, paused: false), .needsPermission)
        XCTAssertEqual(AppState.resolve(trusted: false, subscribed: true, paused: true), .needsPermission)
    }

    func testSubscriptionGatesMonitoring() {
        let state = AppState.resolve(trusted: true, subscribed: false, paused: false)
        XCTAssertEqual(state, .needsSubscription)
        XCTAssertFalse(state.isMonitoring, "no subscription, no Dock locking")
    }

    func testPauseRespectedOnceUnlocked() {
        XCTAssertEqual(AppState.resolve(trusted: true, subscribed: true, paused: true), .paused)
        XCTAssertFalse(AppState.resolve(trusted: true, subscribed: true, paused: true).isMonitoring)
    }

    func testMonitorsOnlyWhenEverythingAllows() {
        let state = AppState.resolve(trusted: true, subscribed: true, paused: false)
        XCTAssertEqual(state, .active)
        XCTAssertTrue(state.isMonitoring)
    }
}
