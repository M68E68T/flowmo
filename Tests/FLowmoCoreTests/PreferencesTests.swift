import XCTest
@testable import FLowmoCore

final class PreferencesTests: XCTestCase {
    func testRenameMigratesPreviousSettingsOnceAndKeepsCurrentValues() throws {
        let newSuite = "FLowmoTests-" + UUID().uuidString
        let oldSuite = "FLowmoMigrationTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: newSuite))
        let previous = try XCTUnwrap(UserDefaults(suiteName: oldSuite))
        defer {
            defaults.removePersistentDomain(forName: newSuite)
            previous.removePersistentDomain(forName: oldSuite)
        }
        previous.set(ModifierCombo.control.rawValue, forKey: "FlostedOpenCombo")
        previous.set(ModifierCombo.command.rawValue, forKey: "FlostedToolsExtra")
        previous.set(0.45, forKey: "FlostedMenuOpacity")
        let expected = Preferences(openCombo: .control, toolsExtra: .command, menuOpacity: 0.45)
        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil,
                                        migratingFromFlosted: previous), expected)
        XCTAssertEqual(defaults.double(forKey: "FLowmoMenuOpacity"), 0.45)
        XCTAssertNil(defaults.object(forKey: "FlostedOpenCombo"))
        XCTAssertEqual(previous.double(forKey: "FlostedMenuOpacity"), 0.45)

        Preferences.default.save(to: defaults)
        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil,
                                        migratingFromFlosted: previous), .default)
    }

    func testSatisfiedRequiresEveryKeyButToleratesExtras() {
        let combo: ModifierCombo = [.control, .option]
        XCTAssertTrue(combo.isSatisfied(by: [.control, .option]))
        XCTAssertTrue(combo.isSatisfied(by: [.control, .option, .command]))
        XCTAssertFalse(combo.isSatisfied(by: [.control]))
        XCTAssertFalse(combo.isSatisfied(by: []))
        XCTAssertFalse(ModifierCombo().isSatisfied(by: .all))
        XCTAssertEqual(ModifierCombo([.command, .shift]).symbols, "⇧⌘")
    }

    func testProblemRejectsEmptyAndOverlappingCombinations() {
        XCTAssertNil(Preferences.default.problem)
        var prefs = Preferences.default
        prefs.openCombo = []
        XCTAssertEqual(prefs.problem, .openComboEmpty)
        prefs.openCombo = [.shift]
        prefs.toolsExtra = [.shift, .command]
        XCTAssertEqual(prefs.problem, .combosOverlap)
        prefs.toolsExtra = []
        XCTAssertNil(prefs.problem, "Kein Werkzeug-Modifier ist erlaubt.")
    }

    func testOpacityIsClampedIntoTheVisibleRange() {
        let low = Preferences(openCombo: .shift, toolsExtra: .option, menuOpacity: -4)
        XCTAssertEqual(low.menuOpacity, Preferences.opacityRange.lowerBound)
        let high = Preferences(openCombo: .shift, toolsExtra: .option, menuOpacity: 9)
        XCTAssertEqual(high.menuOpacity, Preferences.opacityRange.upperBound)
        let broken = Preferences(openCombo: .shift, toolsExtra: .option, menuOpacity: .nan)
        XCTAssertEqual(broken.menuOpacity, Preferences.opacityRange.upperBound, "NaN darf kein unsichtbares Rad ergeben.")
    }

    func testRoundTripAndFallbackForInvalidStoredValues() throws {
        let suite = "FLowmoTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil, migratingFromFlosted: nil), .default,
                       "Leerer Speicher liefert Standardwerte.")

        let stored = Preferences(openCombo: [.control, .option], toolsExtra: .command, menuOpacity: 0.5)
        stored.save(to: defaults)
        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil, migratingFromFlosted: nil), stored)

        // An overlapping combination must never be handed back to the app.
        Preferences(openCombo: [.shift], toolsExtra: [.shift], menuOpacity: 0.5).save(to: defaults)
        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil, migratingFromFlosted: nil), .default)
    }

    func testSettingsAreCarriedOverFromTheOrbitDropBuild() throws {
        let newSuite = "FLowmoTests-" + UUID().uuidString
        let oldSuite = "FLowmoLegacyTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: newSuite))
        let legacy = try XCTUnwrap(UserDefaults(suiteName: oldSuite))
        defer {
            defaults.removePersistentDomain(forName: newSuite)
            legacy.removePersistentDomain(forName: oldSuite)
        }
        legacy.set(ModifierCombo([.control, .option]).rawValue, forKey: "OrbitDropOpenCombo")
        legacy.set(ModifierCombo.command.rawValue, forKey: "OrbitDropToolsExtra")
        legacy.set(0.5, forKey: "OrbitDropMenuOpacity")

        let loaded = Preferences.load(from: defaults, migratingFrom: legacy, migratingFromFlosted: nil)
        XCTAssertEqual(loaded.openCombo, [.control, .option])
        XCTAssertEqual(loaded.toolsExtra, .command)
        XCTAssertEqual(loaded.menuOpacity, 0.5)
        // Written through, so the old domain is only ever read once.
        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: nil, migratingFromFlosted: nil), loaded)
    }

    func testExistingSettingsWinOverTheOldOnes() throws {
        let newSuite = "FLowmoTests-" + UUID().uuidString
        let oldSuite = "FLowmoLegacyTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: newSuite))
        let legacy = try XCTUnwrap(UserDefaults(suiteName: oldSuite))
        defer {
            defaults.removePersistentDomain(forName: newSuite)
            legacy.removePersistentDomain(forName: oldSuite)
        }
        let current = Preferences(openCombo: .shift, toolsExtra: .option, menuOpacity: 0.9)
        current.save(to: defaults)
        legacy.set(ModifierCombo.command.rawValue, forKey: "OrbitDropOpenCombo")

        XCTAssertEqual(Preferences.load(from: defaults, migratingFrom: legacy, migratingFromFlosted: nil), current)
    }
}
