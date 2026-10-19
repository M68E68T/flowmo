import XCTest
@testable import FLowmoCore

final class UndoStackTests: XCTestCase {
    func testAFreshStackGoesNowhere() {
        var stack = UndoStack(0)
        XCTAssertEqual(stack.current, 0)
        XCTAssertFalse(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
        XCTAssertNil(stack.undo())
        XCTAssertNil(stack.redo())
        XCTAssertEqual(stack.current, 0)
    }

    func testUndoAndRedoWalkStepByStep() {
        var stack = UndoStack(0)
        for value in 1...3 { stack.commit(value) }
        XCTAssertEqual(stack.current, 3)

        XCTAssertEqual(stack.undo(), 2)
        XCTAssertEqual(stack.undo(), 1)
        XCTAssertEqual(stack.undo(), 0)
        XCTAssertNil(stack.undo(), "Weiter als zum Anfang geht es nicht.")

        XCTAssertEqual(stack.redo(), 1)
        XCTAssertEqual(stack.redo(), 2)
        XCTAssertEqual(stack.redo(), 3)
        XCTAssertNil(stack.redo())
    }

    func testCommittingAfterUndoDropsTheRedoBranch() {
        var stack = UndoStack(0)
        stack.commit(1)
        stack.commit(2)
        XCTAssertEqual(stack.undo(), 1)
        XCTAssertTrue(stack.canRedo)

        stack.commit(99)
        XCTAssertFalse(stack.canRedo, "Der verlassene Zweig ist nicht mehr erreichbar.")
        XCTAssertEqual(stack.current, 99)
        XCTAssertEqual(stack.undo(), 1, "Zurück führt auf den Stand vor der neuen Änderung.")
    }

    func testTheOldestStateFallsOutAtTheLimit() {
        var stack = UndoStack(0, limit: 2)
        for value in 1...5 { stack.commit(value) }
        XCTAssertEqual(stack.current, 5)
        XCTAssertEqual(stack.undo(), 4)
        XCTAssertEqual(stack.undo(), 3)
        XCTAssertNil(stack.undo(), "Nur zwei Schritte werden vorgehalten.")
        XCTAssertEqual(stack.current, 3)
    }
}
