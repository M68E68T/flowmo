import XCTest
@testable import FLowmoCore

final class WindowPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let size = CGSize(width: 360, height: 500)

    func testPrefersTheRightSideAndKeepsTheGap() {
        let anchor = CGRect(x: 500, y: 200, width: 420, height: 530)
        let frame = WindowPlacement.beside(anchor, size: size, in: screen, gap: 14)
        XCTAssertEqual(frame.minX, anchor.maxX + 14)
        XCTAssertFalse(frame.intersects(anchor), "Fenster dürfen sich nie überdecken.")
        XCTAssertEqual(frame.maxY, anchor.maxY, "Oben bündig mit dem Dashboard.")
        XCTAssertEqual(frame.size, size)
    }

    func testFallsBackToTheLeftWhenTheRightEdgeIsTooClose() {
        let anchor = CGRect(x: 1150, y: 200, width: 420, height: 530)
        let frame = WindowPlacement.beside(anchor, size: size, in: screen, gap: 14)
        XCTAssertEqual(frame.maxX, anchor.minX - 14)
        XCTAssertFalse(frame.intersects(anchor))
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX)
    }

    func testStaysOnScreenWhenNeitherSideFits() {
        let narrow = CGRect(x: 0, y: 0, width: 700, height: 1000)
        let anchor = CGRect(x: 140, y: 200, width: 420, height: 530)
        let frame = WindowPlacement.beside(anchor, size: size, in: narrow, gap: 14)
        XCTAssertTrue(narrow.contains(frame), "Lieber überlappen als vom Bildschirm fallen.")
    }

    func testWideEditorPushesTheDashboardAsideInsteadOfCoveringIt() {
        // Real case: 1440-point screen, dashboard in the middle, 1000-point editor.
        let laptop = CGRect(x: 0, y: 82, width: 1440, height: 788)
        let dashboard = CGRect(x: 720, y: 320, width: 420, height: 550)
        let editor = CGSize(width: 1000, height: 780)
        XCTAssertTrue(WindowPlacement.beside(dashboard, size: editor, in: laptop).intersects(dashboard))
        let placed = WindowPlacement.pair(dashboard, size: editor, in: laptop)
        XCTAssertFalse(placed.window.intersects(placed.anchor), "Fenster dürfen sich nie überdecken.")
        XCTAssertTrue(laptop.contains(placed.window))
        XCTAssertTrue(laptop.contains(placed.anchor))
        XCTAssertEqual(placed.anchor.size, dashboard.size)
        XCTAssertEqual(placed.anchor.minY, dashboard.minY, "Nur seitlich verschieben.")
    }

    func testPairLeavesTheAnchorAloneWhenThereIsRoom() {
        let anchor = CGRect(x: 500, y: 200, width: 420, height: 530)
        let placed = WindowPlacement.pair(anchor, size: size, in: screen)
        XCTAssertEqual(placed.anchor, anchor)
        XCTAssertEqual(placed.window, WindowPlacement.beside(anchor, size: size, in: screen))
    }

    func testPairStillOverlapsOnScreensTooSmallForBoth() {
        let narrow = CGRect(x: 0, y: 0, width: 900, height: 900)
        let anchor = CGRect(x: 200, y: 200, width: 420, height: 530)
        let placed = WindowPlacement.pair(anchor, size: CGSize(width: 720, height: 560), in: narrow)
        XCTAssertEqual(placed.anchor, anchor, "Ohne Platz für beide wird nichts verschoben.")
        XCTAssertTrue(narrow.contains(placed.window))
    }

    func testHandlesAScreenWithANegativeOrigin() {
        let left = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let anchor = CGRect(x: -1800, y: 0, width: 420, height: 530)
        let frame = WindowPlacement.beside(anchor, size: size, in: left, gap: 14)
        XCTAssertEqual(frame.minX, anchor.maxX + 14)
        XCTAssertTrue(left.contains(frame))
    }
}
