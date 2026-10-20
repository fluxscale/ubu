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

#if APP_STORE
@MainActor
final class SubscriptionTextTests: XCTestCase {
    func testPeriodWording() {
        XCTAssertEqual(SubscriptionManager.describe(value: 1, unit: "week"), "1 week")
        XCTAssertEqual(SubscriptionManager.describe(value: 3, unit: "day"), "3 days")
        XCTAssertEqual(SubscriptionManager.unitName(.year), "year")
    }
}
#endif

final class SingleInstanceTests: XCTestCase {
    func testOnlyAnotherCopysRequestQuits() {
        XCTAssertTrue(SingleInstance.isFromAnotherCopy(sender: "200", me: "100"))
        XCTAssertFalse(SingleInstance.isFromAnotherCopy(sender: "100", me: "100"))
        XCTAssertFalse(SingleInstance.isFromAnotherCopy(sender: nil, me: "100"))
    }

    @MainActor
    func testCoversBothEditions() {
        XCTAssertEqual(Set(SingleInstance.bundleIDs), ["com.ubu.app", "com.fluxscale.ubu"])
    }
}
