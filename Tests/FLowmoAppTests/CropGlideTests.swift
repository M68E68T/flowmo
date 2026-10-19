import XCTest
import AppKit
@testable import FLowmo

/// Outside changes to the crop glide; the mouse always moves it 1:1.
final class CropGlideTests: XCTestCase {
    @MainActor private func makeView() throws -> (CropSelectionView, NSWindow) {
        try XCTSkipIf(Motion.reduced, "Reduce Motion is on: the frame jumps by design.")
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let view = CropSelectionView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let context = try XCTUnwrap(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        view.image = try XCTUnwrap(context.makeImage())
        window.contentView = view
        return (view, window)
    }

    @MainActor func testRetargetMidGlideContinuesWithoutJump() throws {
        let (view, window) = try makeView()
        var now = 0.0
        view.clock = { now }
        let first = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        view.selection = first
        XCTAssertEqual(view.displayed, CGRect(x: 0, y: 0, width: 1, height: 1), "Darf nicht sofort springen.")
        now = 0.05; view.step()
        let midway = view.displayed
        XCTAssertGreaterThan(midway.minX, 0); XCTAssertLessThan(midway.minX, first.minX)

        let second = CGRect(x: 0, y: 0.25, width: 1, height: 0.5)
        view.selection = second
        XCTAssertEqual(view.displayed, midway, "Ein neues Ziel muss dort weitermachen, wo der Rahmen gerade ist.")
        now = 0.06; view.step()
        // Heads for the new target from where it was, never back to the old one.
        XCTAssertLessThan(view.displayed.minX, midway.minX)
        XCTAssertGreaterThan(view.displayed.minY, midway.minY)
        now = 0.05 + CropSelectionView.glideDuration + 0.01; view.step()
        XCTAssertEqual(view.displayed, second)
        _ = window
    }

    @MainActor func testMouseMovesTheFrameDirectly() throws {
        let (view, window) = try makeView()
        view.selection = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)   // starts a glide
        func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 150, y: 150)))
        XCTAssertEqual(view.displayed, view.selection, "Ein Griff landet auf dem echten Rahmen.")
        view.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: 170, y: 160)))
        XCTAssertEqual(view.displayed, view.selection, "Die Maus bewegt den Rahmen ohne Nachlauf.")
        view.mouseUp(with: try event(.leftMouseUp, CGPoint(x: 170, y: 160)))
    }
}
