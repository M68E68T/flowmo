import XCTest
import PDFKit
@testable import FlostedCore

final class PageOperationsTests: XCTestCase {
    /// Each page carries its own number so order can be checked after moving.
    private func numberedPDF(_ count: Int) throws -> PDFDocument {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 300, height: 300)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        for number in 1...count {
            context.beginPage(mediaBox: &box)
            let text = NSAttributedString(string: "Seite\(number)", attributes: [
                .font: CTFontCreateWithName("Helvetica" as CFString, 36, nil)])
            let setter = CTFramesetterCreateWithAttributedString(text)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0),
                                                 CGPath(rect: CGRect(x: 30, y: 30, width: 240, height: 240), transform: nil), nil)
            CTFrameDraw(frame, context)
            context.endPage()
        }
        context.closePDF()
        return try XCTUnwrap(PDFDocument(data: data as Data))
    }
    private func order(_ document: PDFDocument) -> [String] {
        (0..<document.pageCount).compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func testRotationStaysWithinAFullTurn() throws {
        let document = try numberedPDF(2)
        PageOperations.rotate(document, pages: IndexSet([0]), by: 90)
        XCTAssertEqual(document.page(at: 0)?.rotation, 90)
        PageOperations.rotate(document, pages: IndexSet([0]), by: 270)
        XCTAssertEqual(document.page(at: 0)?.rotation, 0, "360 Grad müssen wieder 0 ergeben.")
        PageOperations.rotate(document, pages: IndexSet([0]), by: -90)
        XCTAssertEqual(document.page(at: 0)?.rotation, 270, "Rückwärts darf nicht negativ werden.")
        XCTAssertEqual(document.page(at: 1)?.rotation, 0, "Nicht gewählte Seiten bleiben unberührt.")
    }

    /// After reordering, document indices no longer identify the right page —
    /// rotating has to work on the page objects themselves.
    func testRotateByPageObjectSurvivesReordering() throws {
        let document = try numberedPDF(3)
        let third = try XCTUnwrap(document.page(at: 2))
        PageOperations.move(document, from: 2, to: 0)
        PageOperations.rotate([third], by: 90)
        XCTAssertEqual(document.page(at: 0)?.rotation, 90, "Die verschobene Seite wurde gedreht.")
        XCTAssertEqual(document.page(at: 1)?.rotation, 0)
        XCTAssertEqual(document.page(at: 2)?.rotation, 0)
    }

    func testDeleteKeepsTheOrderAndRefusesToEmptyTheDocument() throws {
        let document = try numberedPDF(4)
        try PageOperations.delete(document, pages: IndexSet([1, 2]))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertEqual(order(document), ["Seite1", "Seite4"])
        XCTAssertThrowsError(try PageOperations.delete(document, pages: IndexSet([0, 1])),
                             "Ein PDF ohne Seiten wäre ungültig.")
        XCTAssertEqual(document.pageCount, 2, "Nach dem abgelehnten Versuch bleibt alles stehen.")
    }

    func testMoveReordersWithoutLosingPages() throws {
        let document = try numberedPDF(3)
        PageOperations.move(document, from: 2, to: 0)
        XCTAssertEqual(order(document), ["Seite3", "Seite1", "Seite2"])
        PageOperations.move(document, from: 0, to: 5)   // out of range, ignored
        XCTAssertEqual(order(document), ["Seite3", "Seite1", "Seite2"])
        XCTAssertEqual(document.pageCount, 3)
    }

    func testPagesFromAPDFKeepTheirOrder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("drei.pdf")
        let source = try numberedPDF(3)
        try XCTUnwrap(source.dataRepresentation()).write(to: url)

        let pages = try PageOperations.pages(from: url)
        XCTAssertEqual(pages.count, 3)
        let rebuilt = PDFDocument()
        for (index, page) in pages.enumerated() { rebuilt.insert(page, at: index) }
        XCTAssertEqual(order(rebuilt), ["Seite1", "Seite2", "Seite3"])
        XCTAssertEqual(source.pageCount, 3, "Die Quelle bleibt unverändert.")
    }

    func testAnImageBecomesExactlyOnePageAndStaysInProportion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let context = try ImageTools.canvas(400, 200)
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("bild.png")
        try ImageConverter.encode(image, as: .png).write(to: url)

        let pages = try PageOperations.pages(from: url)
        XCTAssertEqual(pages.count, 1)
        let bounds = try XCTUnwrap(pages.first).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width / bounds.height, 2, accuracy: 0.05, "Seitenverhältnis 2:1 bleibt.")
    }

    func testOversizedImagesAreCappedButKeepTheirProportion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let context = try ImageTools.canvas(3000, 1500)
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("gross.png")
        try ImageConverter.encode(image, as: .png).write(to: url)

        let page = try XCTUnwrap(PageOperations.pages(from: url, maximumEdge: 1000).first)
        let bounds = page.bounds(for: .mediaBox)
        XCTAssertLessThanOrEqual(max(bounds.width, bounds.height), 1001, "Die lange Kante wird begrenzt.")
        XCTAssertEqual(bounds.width / bounds.height, 2, accuracy: 0.05)
    }

    func testUnsupportedFilesThrowInsteadOfProducingAnEmptyPage() {
        let url = URL(fileURLWithPath: "/tmp/datei.xyz")
        XCTAssertThrowsError(try PageOperations.pages(from: url))
        XCTAssertThrowsError(try PageOperations.pages(from: URL(fileURLWithPath: "/tmp/notiz.txt")))
    }

    func testAppendAddsEveryPageInOrder() throws {
        let first = try numberedPDF(2), second = try numberedPDF(3)
        PageOperations.append(first, contentsOf: second)
        XCTAssertEqual(first.pageCount, 5)
        XCTAssertEqual(order(first), ["Seite1", "Seite2", "Seite1", "Seite2", "Seite3"])
        XCTAssertEqual(second.pageCount, 3, "Die Quelle darf sich nicht verändern.")
        XCTAssertFalse(try PageOperations.data(first).isEmpty)
    }
}
