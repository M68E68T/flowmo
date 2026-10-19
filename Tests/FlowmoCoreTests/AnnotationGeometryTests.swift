import XCTest
@testable import FlowmoCore

final class AnnotationGeometryTests: XCTestCase {
    private let rect = CGRect(x: 100, y: 100, width: 200, height: 100)

    func testHandleHitsEveryCornerButNotTheMiddle() {
        for handle in ResizeHandle.allCases {
            let exact = handle.point(in: rect)
            XCTAssertEqual(AnnotationGeometry.handle(at: exact, of: rect), handle)
            let near = CGPoint(x: exact.x + 4, y: exact.y - 4)
            XCTAssertEqual(AnnotationGeometry.handle(at: near, of: rect), handle, "Toleranz muss greifen.")
        }
        XCTAssertNil(AnnotationGeometry.handle(at: CGPoint(x: rect.midX, y: rect.midY), of: rect))
        // Arrows offer only their two ends.
        XCTAssertNil(AnnotationGeometry.handle(at: ResizeHandle.topLeft.point(in: rect), of: rect,
                                               candidates: ResizeHandle.arrowEnds))
        XCTAssertEqual(AnnotationGeometry.handle(at: ResizeHandle.topRight.point(in: rect), of: rect,
                                                 candidates: ResizeHandle.arrowEnds), .topRight)
    }

    func testResizeKeepsTheOppositeCornerFixed() {
        for handle in ResizeHandle.allCases {
            let anchor = handle.opposite.point(in: rect)
            let target = CGPoint(x: anchor.x + 60, y: anchor.y + 40)
            let result = AnnotationGeometry.resize(rect, handle: handle, to: target)
            let stillThere = AnnotationGeometry.handle(at: anchor, of: result, tolerance: 0.001)
            XCTAssertNotNil(stillThere, "\(handle): die Gegenecke darf sich nicht bewegen.")
            XCTAssertEqual(result.width, 60, accuracy: 0.001)
            XCTAssertEqual(result.height, 40, accuracy: 0.001)
        }
    }

    func testResizeStaysValidPastTheAnchorAndAtMinimum() {
        let flipped = AnnotationGeometry.resize(rect, handle: .topRight, to: CGPoint(x: 20, y: 20))
        XCTAssertGreaterThan(flipped.width, 0, "Keine negative Breite.")
        XCTAssertGreaterThan(flipped.height, 0)
        XCTAssertEqual(flipped.maxX, 100, accuracy: 0.001, "Die linke untere Ecke bleibt der Anker.")

        let tiny = AnnotationGeometry.resize(rect, handle: .topRight,
                                             to: ResizeHandle.bottomLeft.point(in: rect))
        XCTAssertEqual(tiny.width, 12, accuracy: 0.001, "Mindestgröße wird eingehalten.")
        XCTAssertEqual(tiny.height, 12, accuracy: 0.001)
    }

    func testArrowCoversAllFourDirections() {
        let origin = CGPoint(x: 50, y: 50)
        let cases: [(CGPoint, Bool, String)] = [
            (CGPoint(x: 150, y: 150), false, "nach oben rechts"),
            (CGPoint(x: -50, y: -50), false, "nach unten links"),
            (CGPoint(x: 150, y: -50), true, "nach unten rechts"),
            (CGPoint(x: -50, y: 150), true, "nach oben links")
        ]
        for (end, expected, name) in cases {
            let result = AnnotationGeometry.arrow(from: origin, to: end)
            XCTAssertEqual(result.flipped, expected, "Diagonale \(name)")
            XCTAssertGreaterThan(result.rect.width, 0, "Rechteck \(name) ist normalisiert.")
            XCTAssertGreaterThan(result.rect.height, 0)
            // Round trip: the ends come back out of the frame.
            let points = AnnotationGeometry.arrowPoints(in: result.rect, flipped: result.flipped, reversed: result.reversed)
            XCTAssertEqual(points.start, origin, "Startpunkt \(name)")
            XCTAssertEqual(points.end, end, "Die Spitze muss dem Zugende \(name) folgen.")
            let handles = AnnotationGeometry.arrowHandles(flipped: result.flipped, reversed: result.reversed)
            XCTAssertEqual(handles[0].point(in: result.rect), origin)
            XCTAssertEqual(handles[1].point(in: result.rect), end)
        }
    }
}
