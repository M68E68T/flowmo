import XCTest
import AppKit
import PDFKit
@testable import FlowmoCore

final class DocumentTests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("document-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: folder) }
    private func document(_ text: String) -> DocumentSnapshot {
        DocumentSnapshot(NSAttributedString(string: text, attributes: DocumentImporter.defaultAttributes))
    }
    private func save(_ data: Data, name: String) throws -> URL {
        let url = folder.appendingPathComponent(name); try data.write(to: url); return url
    }

    func testPagesCoverAllTextAndPDFUsesTheSameLayout() throws {
        let text = "START ÄÖÜ Türkçe\n" + String(repeating: "ABSATZ mit frei fließendem Text. ", count: 600) + "\nENDE"
        let snapshot = document(text)
        let layout = try DocumentLayout(snapshot)
        XCTAssertGreaterThan(layout.containers.count, 2)
        let ranges = layout.containers.map { layout.manager.glyphRange(for: $0) }
        XCTAssertEqual(ranges.first?.location, 0)
        for pair in zip(ranges, ranges.dropFirst()) { XCTAssertEqual(NSMaxRange(pair.0), pair.1.location) }
        XCTAssertEqual(ranges.reduce(0) { $0 + $1.length }, layout.manager.numberOfGlyphs)
        let pdf = try XCTUnwrap(PDFDocument(data: DocumentExporter.data(snapshot, as: .pdf)))
        XCTAssertEqual(pdf.pageCount, layout.containers.count)
        let output = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(output.contains("START")); XCTAssertTrue(output.contains("ENDE"))
        XCTAssertEqual(output.components(separatedBy: "ABSATZ").count - 1, 600)
        let first = try XCTUnwrap(pdf.page(at: 0))
        let selection = try XCTUnwrap(first.selection(for: NSRange(location: 0, length: 5)))
        XCTAssertEqual(selection.bounds(for: first).minX, DocumentLayout.margin, accuracy: 2)
        XCTAssertGreaterThan(selection.bounds(for: first).minY, 770)
    }

    func testDOCXRoundTripKeepsTextFontsAndParagraphFormatting() throws {
        let content = NSMutableAttributedString(string: "ÄÖÜ Türkçe\nZweiter Absatz", attributes: DocumentImporter.defaultAttributes)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        content.addAttributes([.font: NSFont(name: "Helvetica-BoldOblique", size: 20)!,
                               .underlineStyle: NSUnderlineStyle.single.rawValue,
                               .paragraphStyle: paragraph.copy()], range: NSRange(location: 0, length: 10))
        let input = try save(DocumentExporter.data(DocumentSnapshot(content), as: .docx), name: "roundtrip.docx")
        let imported = try DocumentImporter.read(input)
        XCTAssertEqual(imported.document.text.string.trimmingCharacters(in: .newlines), content.string)
        let attrs = imported.document.text.attributes(at: 0, effectiveRange: nil)
        let font = try XCTUnwrap(attrs[.font] as? NSFont)
        XCTAssertEqual(font.pointSize, 20, accuracy: 0.1)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains([.boldFontMask, .italicFontMask]))
        XCTAssertEqual((attrs[.paragraphStyle] as? NSParagraphStyle)?.alignment, .center)
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertFalse(imported.usedOCR)
    }

    func testListConversionAndDOCXDoNotDuplicateMarkers() throws {
        let content = NSMutableAttributedString(attributedString: document("Alpha\nBeta").text)
        let all = NSRange(location: 0, length: content.length)
        DocumentLists.apply(.numbered, to: content, selection: all)
        XCTAssertEqual(content.string, "1.\tAlpha\n2.\tBeta")
        let input = try save(DocumentExporter.data(DocumentSnapshot(content), as: .docx), name: "list.docx")
        let imported = try DocumentImporter.read(input).document.text.string
        XCTAssertEqual(imported.trimmingCharacters(in: .newlines), content.string)
        DocumentLists.apply(.bullet, to: content, selection: NSRange(location: 0, length: content.length))
        XCTAssertEqual(content.string, "•\tAlpha\n•\tBeta")
        DocumentLists.apply(.none, to: content, selection: NSRange(location: 0, length: content.length))
        XCTAssertEqual(content.string, "Alpha\nBeta")
    }

    func testSnapshotsAreImmutableAndSelectionAloneDoesNotChangeHistory() throws {
        let source = NSMutableAttributedString(attributedString: document("Original").text)
        let style = NSMutableParagraphStyle(); style.alignment = .left
        source.addAttribute(.paragraphStyle, value: style.copy(), range: NSRange(location: 0, length: source.length))
        let first = DocumentSnapshot(source)
        var history = UndoStack(first)
        history.commitIfChanged(DocumentSnapshot(source, selection: NSRange(location: 3, length: 2)))
        XCTAssertFalse(history.canUndo)
        source.replaceCharacters(in: NSRange(location: 0, length: source.length), with: "Verändert")
        style.alignment = .right
        source.addAttribute(.paragraphStyle, value: style.copy(), range: NSRange(location: 0, length: source.length))
        XCTAssertEqual(first.text.string, "Original")
        XCTAssertEqual((first.text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .left)
    }

    func testPDFImportReflowsTextAndKeepsSourceUntouched() throws {
        let data = try DocumentExporter.data(document("Erster Absatz mit langem Text. " + String(repeating: "Wort ", count: 250) + "\n\nEnde"), as: .pdf)
        let input = try save(data, name: "source.pdf")
        var progress: [Int] = []
        let result = try DocumentImporter.read(input, progress: { current, _ in progress.append(current) })
        XCTAssertFalse(result.usedOCR)
        XCTAssertTrue(result.document.text.string.contains("Erster Absatz"))
        XCTAssertTrue(result.document.text.string.contains("Ende"))
        XCTAssertTrue(result.document.text.string.contains("Wort Wort"), "PDF-Zeilen müssen wieder fließen.")
        XCTAssertEqual(try Data(contentsOf: input), data)
        XCTAssertEqual(progress.last, 1)
    }

    func testMixedPDFAndImageImportRecognizeScannedText() throws {
        let pixels = try ImageTools.canvas(1000, 300)
        pixels.setFillColor(CGColor(gray: 1, alpha: 1)); pixels.fill(CGRect(x: 0, y: 0, width: 1000, height: 300))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: pixels, flipped: false)
        ("SCAN ALPHA BETA" as NSString).draw(at: CGPoint(x: 40, y: 100), withAttributes: [.font: NSFont(name: "Helvetica-Bold", size: 60)!, .foregroundColor: NSColor.black])
        NSGraphicsContext.restoreGraphicsState()
        let image = try XCTUnwrap(pixels.makeImage())
        let png = try save(ImageConverter.encode(image, as: .png), name: "scan.png")
        XCTAssertTrue(try DocumentImporter.read(png).document.text.string.contains("ALPHA"))
        let textPDF = try XCTUnwrap(PDFDocument(data: DocumentExporter.data(document("NATIVE TEXT"), as: .pdf)))
        let scanned = try XCTUnwrap(PDFPage(image: NSImage(cgImage: image, size: CGSize(width: 500, height: 150))))
        textPDF.insert(scanned, at: 1)
        let input = try save(try XCTUnwrap(textPDF.dataRepresentation()), name: "mixed.pdf")
        let imported = try DocumentImporter.read(input)
        XCTAssertTrue(imported.usedOCR)
        XCTAssertTrue(imported.document.text.string.contains("NATIVE TEXT"))
        XCTAssertTrue(imported.document.text.string.contains("ALPHA"))
    }

    func testImportCancellationEmptyTextAndLockedPDFAreExplicit() throws {
        let input = try save(Data("Noch unverändert".utf8), name: "source.txt")
        XCTAssertThrowsError(try DocumentImporter.read(input, isCancelled: { true })) { XCTAssertTrue($0 is CancellationError) }
        let empty = try save(Data(" \n\t".utf8), name: "empty.txt")
        XCTAssertThrowsError(try DocumentImporter.read(empty)) { guard case ConversionError.noText = $0 else { return XCTFail("\($0)") } }
        let pdf = try XCTUnwrap(PDFDocument(data: DocumentExporter.data(document("LOCKED"), as: .pdf)))
        let locked = folder.appendingPathComponent("locked.pdf")
        XCTAssertTrue(pdf.write(to: locked, withOptions: [.userPasswordOption: "password", .ownerPasswordOption: "owner"]))
        XCTAssertThrowsError(try DocumentImporter.read(locked)) { guard case ConversionError.lockedPDF = $0 else { return XCTFail("\($0)") } }
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)), ["source.txt", "empty.txt", "locked.pdf"])
    }

    func testExportCollisionSafetyAndDocumentMenuEntry() throws {
        let input = try save(Data("Original".utf8), name: "source.txt")
        let snapshot = document("Neu bearbeitet")
        let first = try DocumentExporter.write(snapshot, as: .pdf, beside: input)
        let bytes = try Data(contentsOf: first)
        let second = try DocumentExporter.write(snapshot, as: .pdf, beside: input)
        XCTAssertNotEqual(first, second); XCTAssertEqual(try Data(contentsOf: first), bytes)
        XCTAssertEqual(try String(contentsOf: input), "Original")
        XCTAssertEqual(ActionCatalog.actions(for: [input], tools: true), [.annotate])
        XCTAssertThrowsError(try DocumentExporter.data(snapshot, as: .png))
    }
}
