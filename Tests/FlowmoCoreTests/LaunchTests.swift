import XCTest
@testable import FlowmoCore

final class LaunchTests: XCTestCase {
    func testLoginLaunchStaysInTheMenuBar() {
        XCTAssertEqual(LaunchPlan.make(launchedAtLogin: true, introSeen: false),
                       LaunchPlan(showsDashboard: false, showsIntroduction: false))
        XCTAssertEqual(LaunchPlan.make(launchedAtLogin: true, introSeen: true),
                       LaunchPlan(showsDashboard: false, showsIntroduction: false))
    }

    func testFirstOpenShowsTheIntroductionLaterOnesDoNot() {
        XCTAssertEqual(LaunchPlan.make(launchedAtLogin: false, introSeen: false),
                       LaunchPlan(showsDashboard: true, showsIntroduction: true))
        XCTAssertEqual(LaunchPlan.make(launchedAtLogin: false, introSeen: true),
                       LaunchPlan(showsDashboard: true, showsIntroduction: false))
    }

    /// Switched on once per location; a user who turns it off is never overruled.
    func testLoginItemFollowsAMoveButNeverOverrulesTheUser() throws {
        let name = "flowmoLaunchTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let downloads = "/Users/x/Downloads/flowmo.app", applications = "/Applications/flowmo.app"
        XCTAssertTrue(LoginItemState.shouldRegister(at: downloads, defaults), "erster Start")
        LoginItemState.registered(at: downloads, defaults)
        XCTAssertFalse(LoginItemState.shouldRegister(at: downloads, defaults), "nur einmal")
        XCTAssertTrue(LoginItemState.shouldRegister(at: applications, defaults), "nach dem Verschieben neu")
        LoginItemState.registered(at: applications, defaults)
        LoginItemState.declined(defaults)
        XCTAssertFalse(LoginItemState.shouldRegister(at: applications, defaults))
        XCTAssertFalse(LoginItemState.shouldRegister(at: downloads, defaults), "aus bleibt aus, auch woanders")
        LoginItemState.registered(at: applications, defaults)   // switched back on by hand
        XCTAssertFalse(LoginItemState.shouldRegister(at: applications, defaults))
    }

    func testTranslocatedCopyIsNotRegistered() {
        XCTAssertFalse(LoginItemState.canRegister(
            bundlePath: "/private/var/folders/x/AppTranslocation/1234/d/flowmo.app"))
        XCTAssertTrue(LoginItemState.canRegister(bundlePath: "/Applications/flowmo.app"))
    }
}
