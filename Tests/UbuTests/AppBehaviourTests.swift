import XCTest
@testable import ubu

final class AppBehaviourTests: XCTestCase {

    func testLoginItemIsClaimedOnlyOnFirstLaunch() throws {
        let suite = "ubu.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertTrue(LoginItemManager.claimFirstLaunch(defaults))
        XCTAssertFalse(LoginItemManager.claimFirstLaunch(defaults), "a user who turned it off stays off")
        XCTAssertFalse(LoginItemManager.claimFirstLaunch(defaults))
    }

    #if !APP_STORE
    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.compareVersions("1.1.0", isNewerThan: "1.0.2"))
        XCTAssertTrue(UpdateChecker.compareVersions("1.0.10", isNewerThan: "1.0.9"), "numeric, not lexical")
        XCTAssertTrue(UpdateChecker.compareVersions("2.0", isNewerThan: "1.9.9"))
        XCTAssertFalse(UpdateChecker.compareVersions("1.0.2", isNewerThan: "1.0.2"))
        XCTAssertFalse(UpdateChecker.compareVersions("1.0", isNewerThan: "1.0.0"))
        XCTAssertFalse(UpdateChecker.compareVersions("1.0.1", isNewerThan: "1.0.2"))
    }
    #endif
}
