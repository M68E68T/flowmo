import XCTest
import AppKit
import FlowmoCore
@testable import Flowmo

/// Offscreen view tests: no events are posted to the user's desktop.
final class CanvasBehaviorTests: XCTestCase {
    @MainActor private func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    @MainActor func testNewContentFrameExistsBeforeRequestAndIsNotCommitted() async throws {
        for tool in [AnnotationTool.text, .signature] {
            let view = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
            view.tool = tool
            var commits = 0, requested: UUID?
            view.committed = { _ in commits += 1 }
            view.requestsText = { requested = $0 }
            view.requestsSignature = { requested = $0 }
            view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 100, y: 100)))
            view.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 100, y: 100)))
            XCTAssertEqual(view.annotations.count, 1)
            XCTAssertEqual(requested, view.annotations.first?.id)
            XCTAssertEqual(commits, 0, "Unfertige Rahmen dürfen keinen Undo-Schritt erzeugen.")
        }
    }

    @MainActor func testCanvasReportsSelectionToItsOwner() async throws {
        let view = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let box = Annotation(kind: .rectangle, frame: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        view.annotations = [box]
        var selection: UUID?
        view.selectionChanged = { selection = $0 }
        view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 100, y: 100)))
        view.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 100, y: 100)))
        XCTAssertEqual(selection, box.id)
        view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 350, y: 350)))
        XCTAssertNil(selection)
    }

    @MainActor func testNewArrowsPreserveAllDirectionsIncludingStraightLines() async throws {
        let origin = CGPoint(x: 200, y: 200)
        for tip in [CGPoint(x: 300, y: 300), CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100),
                    CGPoint(x: 100, y: 300), CGPoint(x: 100, y: 200), CGPoint(x: 200, y: 100)] {
            let view = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            view.tool = .arrow
            view.mouseDown(with: try event(.leftMouseDown, at: origin))
            view.mouseDragged(with: try event(.leftMouseDragged, at: tip))
            view.mouseUp(with: try event(.leftMouseUp, at: tip))
            let arrow = try XCTUnwrap(view.annotations.first, "\(tip)")
            let points = AnnotationGeometry.arrowPoints(in: arrow.rect(in: view.bounds),
                flipped: arrow.arrowFlipped, reversed: arrow.arrowReversed)
            XCTAssertEqual(points.start, origin)
            XCTAssertEqual(points.end, tip)
        }
    }

    @MainActor func testIllustrationHasNoActionsOrTrackingAndEmptyWheelHasNoGlass() async throws {
        let illustration = RadialMenuView(frame: CGRect(x: 0, y: 0, width: 250, height: 250), interactive: false)
        illustration.actions = [.crop, .background]
        illustration.updateTrackingAreas()
        XCTAssertTrue(illustration.trackingAreas.isEmpty)
        XCTAssertTrue(illustration.registeredDraggedTypes.isEmpty)
        XCTAssertTrue(illustration.accessibilityChildren()?.isEmpty ?? true)
        let dropTarget = RadialMenuView(frame: CGRect(x: 0, y: 0, width: 336, height: 336))
        XCTAssertTrue(try XCTUnwrap(dropTarget.subviews.first as? NSVisualEffectView).isHidden)
        XCTAssertFalse(dropTarget.registeredDraggedTypes.isEmpty, "Der leere Kreis muss ein Drop-Ziel bleiben.")
        dropTarget.actions = [.convert(.jpg)]
        XCTAssertFalse(try XCTUnwrap(dropTarget.subviews.first as? NSVisualEffectView).isHidden)
    }

    @MainActor func testArrowTipCanCrossTheStartWithoutMovingItsAnchor() async throws {
        let view = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let original = Annotation(kind: .arrow, frame: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
                                  arrowFlipped: true, arrowReversed: true)
        view.annotations = [original]; view.selected = original.id
        let fixed = AnnotationGeometry.arrowPoints(in: original.rect(in: view.bounds), flipped: true, reversed: true)
        view.mouseDown(with: try event(.leftMouseDown, at: fixed.end))
        // Cross the fixed end and then move again in the new quadrant.
        for point in [CGPoint(x: 350, y: 350), CGPoint(x: 360, y: 370)] {
            view.mouseDragged(with: try event(.leftMouseDragged, at: point))
            let result = try XCTUnwrap(view.annotations.first)
            let ends = AnnotationGeometry.arrowPoints(in: result.rect(in: view.bounds),
                flipped: result.arrowFlipped, reversed: result.arrowReversed)
            XCTAssertEqual(ends.start, fixed.start)
            XCTAssertEqual(ends.end, point)
        }
    }

    @MainActor func testSelectingWithoutMovingDoesNotConsumeUndoHistory() async throws {
        let view = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let box = Annotation(kind: .rectangle, frame: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        view.annotations = [box]
        var history = UndoStack([box])
        view.committed = { history.commitIfChanged($0) }
        for _ in 0..<60 {
            view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 100, y: 100)))
            view.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 100, y: 100)))
        }
        XCTAssertFalse(history.canUndo, "Auswahlklicks dürfen keine echten Änderungen aus dem Verlauf verdrängen.")
    }
    @MainActor func testDrawingSurfacesNeverDragTheWindow() async throws {
        // ReferenceWindow moves by its background; a stroke on these views
        // used to move the whole window by the length of the stroke.
        XCTAssertTrue(ReferenceWindow(size: CGSize(width: 300, height: 200), title: "Test").isMovableByWindowBackground)
        XCTAssertFalse(AnnotationCanvasView(frame: .zero).mouseDownCanMoveWindow)
        XCTAssertFalse(CropSelectionView(frame: .zero).mouseDownCanMoveWindow)
        XCTAssertFalse(PageDragSource.SourceView(frame: .zero).mouseDownCanMoveWindow)
    }

    @MainActor func testCropGripOutsideTheImageStillResizes() async throws {
        let context = try ImageTools.canvas(400, 200)
        let view = CropSelectionView(frame: CGRect(x: 0, y: 0, width: 444, height: 244))
        view.image = try XCTUnwrap(context.makeImage())
        var result: CGRect?
        view.changed = { result = $0 }
        // Full selection: the top-right grip sits on the image corner (422, 222).
        // Press its outer half, beyond the image but inside the view.
        view.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 427, y: 227)))
        view.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: 322, y: 172)))
        let crop = try XCTUnwrap(result, "Der Griff muss auch außerhalb des Bildes greifen.")
        XCTAssertEqual(crop.minX, 0, accuracy: 0.001)
        XCTAssertEqual(crop.width, 0.75, accuracy: 0.001)
        XCTAssertEqual(crop.height, 0.75, accuracy: 0.001)
    }

    @MainActor func testEditorWindowRoutesUndoRedoAndZoomWithoutPostingKeys() async throws {
        let window = ReferenceWindow(size: CGSize(width: 300, height: 200), title: "Test")
        var undos = 0, redos = 0, fits = 0, zooms = 0
        window.editorCommands = EditorWindowCommands(canUndo: { true }, canRedo: { true },
            undo: { undos += 1 }, redo: { redos += 1 }, fit: { fits += 1 }, zoom: { zooms += $0 })
        for (key, flags) in [("z", NSEvent.ModifierFlags.command), ("z", [.command, .shift]),
                             ("0", .command), ("+", .command), ("-", .command)] {
            let keyEvent = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0))
            XCTAssertTrue(window.performKeyEquivalent(with: keyEvent))
        }
        XCTAssertEqual(undos, 1)
        XCTAssertEqual(redos, 1)
        XCTAssertEqual(fits, 1)
        XCTAssertEqual(zooms, 0)
    }

}
