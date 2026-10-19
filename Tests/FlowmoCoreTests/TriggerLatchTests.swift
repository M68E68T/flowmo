import XCTest
@testable import FlowmoCore

final class TriggerLatchTests: XCTestCase {
    func testHoldingTheKeysOpensOnlyOnce() {
        var latch = TriggerLatch()
        XCTAssertTrue(latch.update(armed: true, satisfied: true), "Erster Druck öffnet.")
        XCTAssertFalse(latch.update(armed: true, satisfied: true), "Halten darf nicht erneut öffnen.")
        XCTAssertFalse(latch.update(armed: true, satisfied: true))
    }

    /// The reported bug: after the wheel was dismissed mid-drag, pressing the
    /// keys again did nothing until the file was dropped.
    func testReleasingAndPressingAgainOpensAgain() {
        var latch = TriggerLatch()
        XCTAssertTrue(latch.update(armed: true, satisfied: true))
        XCTAssertFalse(latch.update(armed: true, satisfied: false), "Loslassen öffnet nichts.")
        XCTAssertTrue(latch.update(armed: true, satisfied: true), "Erneutes Drücken öffnet wieder.")
        XCTAssertFalse(latch.update(armed: true, satisfied: false))
        XCTAssertTrue(latch.update(armed: true, satisfied: true), "Und beliebig oft.")
    }

    func testKeysHeldBeforeArmingStillCount() {
        var latch = TriggerLatch()
        XCTAssertFalse(latch.update(armed: false, satisfied: true), "Ohne Drag passiert nichts.")
        XCTAssertFalse(latch.update(armed: false, satisfied: true))
        XCTAssertTrue(latch.update(armed: true, satisfied: true),
                      "Scharf werden bei gehaltener Taste zählt als frischer Druck.")
        XCTAssertFalse(latch.update(armed: true, satisfied: true))
    }

    func testEndOfSessionRestoresTheStartingState() {
        var latch = TriggerLatch()
        XCTAssertTrue(latch.update(armed: true, satisfied: true))
        XCTAssertFalse(latch.update(armed: false, satisfied: true), "Maustaste losgelassen.")
        XCTAssertFalse(latch.isHeld)
        XCTAssertTrue(latch.update(armed: true, satisfied: true), "Die nächste Sitzung beginnt frisch.")
    }
}
