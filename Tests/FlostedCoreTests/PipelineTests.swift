import XCTest
import PDFKit
import CoreText
@testable import FlostedCore

/// End-to-end coverage for the two paths that depend on what this particular
/// Mac can actually do: the system image encoders and local text recognition.
/// Both were long assumed to work rather than demonstrated.
final class PipelineTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("pipeline-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    private func colourfulPNG() throws -> URL {
        let context = try ImageTools.canvas(240, 160)
        for (index, grey) in [0.2, 0.5, 0.8].enumerated() {
            context.setFillColor(CGColor(gray: grey, alpha: 1))
            context.fill(CGRect(x: index * 80, y: 0, width: 80, height: 160))
        }
        let url = folder.appendingPathComponent("muster.png")
        try ImageConverter.encode(try XCTUnwrap(context.makeImage()), as: .png).write(to: url)
        return url
    }

    /// Every format the wheel offers has to produce a file that reads back.
    /// A Mac missing an encoder must drop it from the menu, not fail at save.
    func testEveryOfferedImageFormatEncodesAndReadsBack() throws {
        let source = try colourfulPNG()
        let offered = ActionCatalog.actions(for: [source], tools: false)
        XCTAssertFalse(offered.isEmpty)
        for action in offered {
            guard case .convert(let format) = action else { continue }
            let url = try XCTUnwrap(try FileConverter.convert(source, to: format).first)
            XCTAssertGreaterThan(try Data(contentsOf: url).count, 100, "\(format.rawValue) ist leer")
            if format != .pdf {
                XCTAssertNoThrow(try ImageConverter.decode(url),
                                 "\(format.rawValue) wird angeboten, lässt sich aber nicht wieder lesen")
            }
        }
    }

    /// A page carrying text only as pixels: without OCR this yields nothing.
    func testTextRecognitionReadsAScannedPage() throws {
        let canvas = try ImageTools.canvas(1000, 400)
        canvas.setFillColor(CGColor(gray: 0.98, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: 1000, height: 400))
        let attributed = NSAttributedString(string: "GESCANNTER TEXT", attributes: [
            .font: CTFontCreateWithName("Helvetica-Bold" as CFString, 64, nil),
            .foregroundColor: CGColor(gray: 0.05, alpha: 1)])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0),
                                             CGPath(rect: CGRect(x: 40, y: 120, width: 920, height: 200), transform: nil), nil),
                    canvas)
        let pixels = try XCTUnwrap(canvas.makeImage())

        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 500, height: 200)
        let pdf = try XCTUnwrap(CGContext(consumer: try XCTUnwrap(CGDataConsumer(data: data)), mediaBox: &box, nil))
        pdf.beginPage(mediaBox: &box); pdf.draw(pixels, in: box); pdf.endPage(); pdf.closePDF()
        let scan = folder.appendingPathComponent("scan.pdf")
        try (data as Data).write(to: scan)
        XCTAssertTrue((try FileConverter.pdf(scan).page(at: 0)?.string ?? "").isEmpty,
                      "Vorbedingung: die Seite trägt keine Textebene")

        let recognized = try String(contentsOf: try XCTUnwrap(try FileConverter.convert(scan, to: .txt).first),
                                    encoding: .utf8)
        let upper = recognized.uppercased()
        XCTAssertTrue(upper.contains("GESCANNTER") && upper.contains("TEXT"),
                      "Texterkennung lieferte: \(recognized.prefix(120))")
    }
}
