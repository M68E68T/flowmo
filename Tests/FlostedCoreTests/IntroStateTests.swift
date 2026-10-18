import XCTest
@testable import FlostedCore

final class IntroStateTests: XCTestCase {
    private func suite() throws -> (UserDefaults, String) {
        let name = "FlostedIntroTests-" + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }

    func testFreshInstallHasNotSeenTheIntroduction() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(IntroState.hasSeen(defaults))
    }

    func testMarkingAndResetting() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        IntroState.markSeen(defaults)
        XCTAssertTrue(IntroState.hasSeen(defaults))
        IntroState.reset(defaults)
        XCTAssertFalse(IntroState.hasSeen(defaults), "Nach dem Zurücksetzen wird sie wieder gezeigt.")
    }

    /// The reason the flag lives outside Preferences: resetting the settings
    /// must not drag the introduction back onto the screen.
    func testResettingThePreferencesLeavesTheFlagAlone() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        IntroState.markSeen(defaults)

        Preferences.default.save(to: defaults)
        XCTAssertTrue(IntroState.hasSeen(defaults))
        _ = Preferences.load(from: defaults, migratingFrom: nil)
        XCTAssertTrue(IntroState.hasSeen(defaults), "Einstellungen zurücksetzen darf die Einleitung nicht erneut auslösen.")
    }
}
