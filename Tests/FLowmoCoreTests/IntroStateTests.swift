import XCTest
@testable import FLowmoCore

final class IntroStateTests: XCTestCase {
    func testRenamePreservesSeenStateAndDoesNotUndoReset() throws {
        let (defaults, name) = try suite()
        let (previous, oldName) = try suite()
        defer {
            defaults.removePersistentDomain(forName: name)
            previous.removePersistentDomain(forName: oldName)
        }
        previous.set(true, forKey: "FlostedIntroSeen")
        XCTAssertTrue(IntroState.hasSeen(defaults, migratingFromFlosted: previous))
        XCTAssertTrue(defaults.bool(forKey: "FLowmoIntroSeen"))
        IntroState.reset(defaults)
        XCTAssertFalse(IntroState.hasSeen(defaults, migratingFromFlosted: previous))
        XCTAssertTrue(previous.bool(forKey: "FlostedIntroSeen"))
    }

    private func suite() throws -> (UserDefaults, String) {
        let name = "FLowmoIntroTests-" + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }

    func testFreshInstallHasNotSeenTheIntroduction() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(IntroState.hasSeen(defaults, migratingFromFlosted: nil))
    }

    func testMarkingAndResetting() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        IntroState.markSeen(defaults)
        XCTAssertTrue(IntroState.hasSeen(defaults, migratingFromFlosted: nil))
        IntroState.reset(defaults)
        XCTAssertFalse(IntroState.hasSeen(defaults, migratingFromFlosted: nil), "Nach dem Zurücksetzen wird sie wieder gezeigt.")
    }

    /// The reason the flag lives outside Preferences: resetting the settings
    /// must not drag the introduction back onto the screen.
    func testResettingThePreferencesLeavesTheFlagAlone() throws {
        let (defaults, name) = try suite()
        defer { defaults.removePersistentDomain(forName: name) }
        IntroState.markSeen(defaults)

        Preferences.default.save(to: defaults)
        XCTAssertTrue(IntroState.hasSeen(defaults, migratingFromFlosted: nil))
        _ = Preferences.load(from: defaults, migratingFrom: nil, migratingFromFlosted: nil)
        XCTAssertTrue(IntroState.hasSeen(defaults, migratingFromFlosted: nil), "Einstellungen zurücksetzen darf die Einleitung nicht erneut auslösen.")
    }
}
