import XCTest
import PDFKit
import CoreGraphics
@testable import FlostedCore

final class AnnotationTests: XCTestCase {
    private func solidImage(_ width: Int, _ height: Int) throws -> CGImage {
        let context = try ImageTools.canvas(width, height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }
    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) throws -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let context = try ImageTools.canvas(image.width, image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * image.height)
        // Bitmap rows run top-down, the annotation frame bottom-up.
        let offset = (image.height - 1 - y) * context.bytesPerRow + x * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
    /// Darkest red value in a small window, which tolerates antialiasing and
    /// a line that lands a pixel off.
    private func darkest(_ image: CGImage, _ x: Int, _ y: Int, radius: Int = 3) throws -> Int {
        var lowest = 255
        for dx in -radius...radius {
            for dy in -radius...radius {
                let px = x + dx, py = y + dy
                guard px >= 0, py >= 0, px < image.width, py < image.height else { continue }
                lowest = min(lowest, Int(try pixel(image, px, py).r))
            }
        }
        return lowest
    }
    /// Text with a known string, so the redaction test can look for it again.
    private func textPDF(_ pages: [String]) throws -> PDFDocument {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 400, height: 400)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        for text in pages {
            context.beginPage(mediaBox: &box)
            let attributed = NSAttributedString(string: text, attributes: [
                .font: CTFontCreateWithName("Helvetica" as CFString, 28, nil)])
            let setter = CTFramesetterCreateWithAttributedString(attributed)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0),
                                                 CGPath(rect: CGRect(x: 40, y: 40, width: 320, height: 320), transform: nil), nil)
            CTFrameDraw(frame, context)
            context.endPage()
        }
        context.closePDF()
        return try XCTUnwrap(PDFDocument(data: data as Data))
    }

    func testNormalizedFrameMapsOntoTheCanvas() {
        let annotation = Annotation(kind: .rectangle, frame: CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25))
        let rect = annotation.rect(in: CGRect(x: 0, y: 0, width: 400, height: 200))
        XCTAssertEqual(rect, CGRect(x: 100, y: 100, width: 200, height: 50))
        // An offset canvas, as used for a PDF page that does not start at zero.
        let shifted = annotation.rect(in: CGRect(x: 10, y: 20, width: 400, height: 200))
        XCTAssertEqual(shifted.minX, 110)
        XCTAssertEqual(shifted.minY, 120)
    }

    func testRasterizingIsOnlyRequiredForRedaction() {
        let list = [Annotation(kind: .text("hi"), frame: .zero, page: 0),
                    Annotation(kind: .redaction, frame: .zero, page: 2)]
        XCTAssertFalse(list.requiresRasterizing(page: 0))
        XCTAssertFalse(list.requiresRasterizing(page: 1))
        XCTAssertTrue(list.requiresRasterizing(page: 2), "Nur die geschwärzte Seite darf gerastert werden.")
        XCTAssertEqual(list.on(page: 2).count, 1)
    }

    func testDrawingOnAnImageHitsTheRightAreaOnly() throws {
        let source = try solidImage(100, 100)
        let mark = Annotation(kind: .redaction, frame: CGRect(x: 0, y: 0, width: 0.4, height: 0.4))
        let result = try AnnotationRenderer.render([mark], on: source)
        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 100)
        let inside = try pixel(result, 10, 10), outside = try pixel(result, 90, 90)
        XCTAssertLessThan(Int(inside.r), 40, "Innerhalb der Markierung muss es dunkel sein.")
        XCTAssertGreaterThan(Int(outside.r), 200, "Außerhalb darf sich nichts ändern.")
    }

    func testPDFKeepsItsTextWhenNothingIsRedacted() throws {
        let document = try textPDF(["Vertraulich Alpha", "Seite Zwei Beta"])
        let note = Annotation(kind: .text("Geprüft"), frame: CGRect(x: 0.1, y: 0.8, width: 0.5, height: 0.1), page: 0)
        let data = try AnnotationRenderer.render([note], into: document)
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(result.pageCount, 2)
        let page = try XCTUnwrap(result.page(at: 0))
        XCTAssertTrue((page.string ?? "").contains("Vertraulich"),
                      "Ohne Schwärzung wird durchgereicht, der Text bleibt durchsuchbar.")
    }

    /// The core safety property: a black bar must not merely hide the text.
    func testRedactedTextIsPhysicallyGoneButOtherPagesKeepTheirs() throws {
        let document = try textPDF(["Geheimnis Alpha", "Harmlos Beta"])
        let bar = Annotation(kind: .redaction, frame: CGRect(x: 0, y: 0, width: 1, height: 1), page: 0)
        let data = try AnnotationRenderer.render([bar], into: document)
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(result.pageCount, 2)
        let redacted = try XCTUnwrap(result.page(at: 0)).string ?? ""
        XCTAssertFalse(redacted.contains("Geheimnis"), "Geschwärzter Text darf nicht extrahierbar bleiben.")
        let untouched = try XCTUnwrap(result.page(at: 1)).string ?? ""
        XCTAssertTrue(untouched.contains("Harmlos"), "Andere Seiten behalten ihre Textebene.")
    }

    func testCompletenessDecidesWhatMayBeExported() {
        let known: Set<String> = ["abc"]
        func make(_ kind: AnnotationKind) -> Annotation {
            Annotation(kind: kind, frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertFalse(make(.text("")).isComplete(signatures: known))
        XCTAssertFalse(make(.text("   \n ")).isComplete(signatures: known), "Nur Leerraum zeichnet nichts.")
        XCTAssertTrue(make(.text("Hallo")).isComplete(signatures: known))
        XCTAssertFalse(make(.signature(id: "")).isComplete(signatures: known),
                       "Eine nicht zugewiesene Signatur darf nicht exportiert werden.")
        XCTAssertFalse(make(.signature(id: "weg")).isComplete(signatures: known))
        XCTAssertTrue(make(.signature(id: "abc")).isComplete(signatures: known))
        for kind in [AnnotationKind.arrow, .rectangle, .highlight, .redaction] {
            XCTAssertTrue(make(kind).isComplete(signatures: []), "\(kind) braucht keinen Inhalt.")
        }
        let mixed = [make(.text("")), make(.text("da")), make(.signature(id: "abc"))]
        XCTAssertEqual(mixed.complete(signatures: known).count, 2)
    }

    /// Counterpart to testDrawingOnAnImageHitsTheRightAreaOnly: unfinished
    /// elements must leave the file looking exactly like the original.
    func testUnfinishedElementsLeaveTheImageUntouched() throws {
        let source = try solidImage(40, 40)
        let unfinished = [Annotation(kind: .text(" "), frame: CGRect(x: 0, y: 0, width: 1, height: 1)),
                          Annotation(kind: .signature(id: "fehlt"), frame: CGRect(x: 0, y: 0, width: 1, height: 1))]
        let result = try AnnotationRenderer.render(unfinished, on: source)
        for point in [(5, 5), (20, 20), (35, 35)] {
            XCTAssertGreaterThan(Int(try pixel(result, point.0, point.1).r), 200,
                                 "An \(point) darf sich nichts geändert haben.")
        }
    }

    /// The direction has to survive all the way into the rendered output,
    /// not just look right in the preview.
    func testArrowDirectionReachesTheOutput() throws {
        let source = try solidImage(60, 60)
        let frame = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        // Black, not the accent colour: that one's red channel is 0.87 and
        // would be nearly indistinguishable from the white background.
        var style = AnnotationStyle(); style.lineWidth = 6; style.color = RGB(0, 0, 0)
        let rising = Annotation(kind: .arrow, frame: frame, style: style)
        let falling = Annotation(kind: .arrow, frame: frame, style: style, arrowFlipped: true)

        let a = try AnnotationRenderer.render([rising], on: source)
        let b = try AnnotationRenderer.render([falling], on: source)

        // Measured mid-diagonal, away from the head and the line caps.
        // Rising runs through (20,20), falling through (20,40).
        XCTAssertLessThan(try darkest(a, 20, 20), 150, "Steigender Pfeil läuft durch (20,20).")
        XCTAssertGreaterThan(try darkest(b, 20, 20), 200, "Fallender Pfeil nicht.")
        XCTAssertLessThan(try darkest(b, 20, 40), 150, "Fallender Pfeil läuft durch (20,40).")
        XCTAssertGreaterThan(try darkest(a, 20, 40), 200, "Steigender Pfeil nicht.")
    }

    func testSignatureStoreRoundTripAndWhiteRemoval() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FlostedSig-" + UUID().uuidString)
        let store = SignatureStore(folder: folder)
        defer { try? FileManager.default.removeItem(at: folder) }

        let context = try ImageTools.canvas(20, 20)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 10, height: 20))
        let drawn = try XCTUnwrap(context.makeImage())

        let id = try store.save(drawn)
        XCTAssertNotNil(store.load()[id])
        store.remove(id: id)
        XCTAssertNil(store.load()[id], "Nach dem Löschen darf die Signatur nicht mehr auftauchen.")

        let cleaned = try SignatureStore.removingWhiteBackground(drawn)
        XCTAssertEqual(try pixel(cleaned, 15, 10).a, 0, "Weißes Papier wird transparent.")
        XCTAssertGreaterThan(Int(try pixel(cleaned, 5, 10).a), 200, "Die Striche bleiben erhalten.")
    }
}
