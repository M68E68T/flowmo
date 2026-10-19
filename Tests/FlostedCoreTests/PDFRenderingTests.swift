import XCTest
import PDFKit
import CoreText
@testable import FlostedCore

final class PDFRenderingTests: XCTestCase {
    // Bottom-left, bottom-right, top-left, top-right after clockwise rotation.
    private let blue = RGB(0, 0, 1), yellow = RGB(1, 1, 0)
    private let red = RGB(1, 0, 0), green = RGB(0, 1, 0)

    private func corners(rotation: Int) -> [RGB] {
        switch rotation {
        case 90: return [yellow, green, blue, red]
        case 180: return [green, red, yellow, blue]
        case 270: return [red, blue, green, yellow]
        default: return [blue, yellow, red, green]
        }
    }

    private func document(origin: CGPoint = .zero, margin: CGFloat = 0,
                          text: Bool = false) throws -> PDFDocument {
        let data = NSMutableData()
        var box = CGRect(origin: origin, size: CGSize(width: 144, height: 96))
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPage(mediaBox: &box)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(box)
        let inner = box.insetBy(dx: margin, dy: margin)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        for (index, color) in [blue, yellow, red, green].enumerated() {
            context.setFillColor(try XCTUnwrap(CGColor(colorSpace: space,
                components: [color.red, color.green, color.blue, 1])))
            context.fill(CGRect(x: inner.minX + (index % 2 == 0 ? 0 : inner.width / 2),
                                y: inner.minY + (index < 2 ? 0 : inner.height / 2),
                                width: inner.width / 2, height: inner.height / 2))
        }
        if text {
            let value = NSAttributedString(string: "SECRET", attributes: [
                .font: CTFontCreateWithName("Helvetica" as CFString, 10, nil),
                .foregroundColor: CGColor(gray: 0, alpha: 1)])
            context.textPosition = CGPoint(x: box.minX + 10, y: box.minY + 20)
            CTLineDraw(CTLineCreateWithAttributedString(value), context)
        }
        context.endPage(); context.closePDF()
        return try XCTUnwrap(PDFDocument(data: data as Data))
    }

    private func assertPixel(_ image: CGImage, x: Double, y: Double, color: RGB,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        // Compare in the fixture colors' sRGB space, independent of the Mac's
        // device RGB profile (which may use a wider gamut).
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let px = Int(Double(image.width - 1) * x)
        let py = Int(Double(image.height - 1) * y)
        let offset = (image.height - 1 - py) * context.bytesPerRow + px * 4
        for (channel, expected) in [color.red, color.green, color.blue].enumerated() {
            XCTAssertEqual(Double(bytes[offset + channel]) / 255, expected, accuracy: 0.08,
                           "Pixel (\(x), \(y)), Kanal \(channel)", file: file, line: line)
        }
    }

    private func assertCorners(_ image: CGImage, rotation: Int,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        for (index, color) in corners(rotation: rotation).enumerated() {
            try assertPixel(image, x: index % 2 == 0 ? 0.08 : 0.92,
                            y: index < 2 ? 0.08 : 0.92, color: color, file: file, line: line)
        }
    }

    func testContentFillsThePageAtEveryResolutionAndRotation() throws {
        for origin in [CGPoint.zero, CGPoint(x: 35, y: -20)] {
            let source = try document(origin: origin)
            for rotation in [0, 90, 180, 270] {
                let page = try XCTUnwrap(source.page(at: 0))
                page.rotation = rotation
                for dpi in [36.0, 72, 110, 150, 200] {
                    let image = try FileConverter.render(page, dpi: dpi)
                    XCTAssertEqual(image.width, Int(ceil(Double(rotation % 180 == 0 ? 144 : 96) * dpi / 72)))
                    XCTAssertEqual(image.height, Int(ceil(Double(rotation % 180 == 0 ? 96 : 144) * dpi / 72)))
                    try assertCorners(image, rotation: rotation)
                }
            }
        }
    }

    func testActualPageMarginsArePreserved() throws {
        let source = try document(margin: 12)
        let image = try FileConverter.render(try XCTUnwrap(source.page(at: 0)))
        for (x, y) in [(0.02, 0.5), (0.98, 0.5), (0.5, 0.02), (0.5, 0.98)] {
            try assertPixel(image, x: x, y: y, color: RGB(1, 1, 1))
        }
        try assertPixel(image, x: 0.25, y: 0.25, color: blue)
        try assertPixel(image, x: 0.75, y: 0.75, color: green)
    }

    func testJPGAndPNGExportEveryPageWithoutAddingMargins() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try document()
        let rotated = try document()
        let page = try XCTUnwrap(rotated.page(at: 0)?.copy() as? PDFPage)
        page.rotation = 90
        source.insert(page, at: 1)
        let input = folder.appendingPathComponent("quadrants.pdf")
        let original = try XCTUnwrap(source.dataRepresentation())
        try original.write(to: input)
        for format in [OutputFormat.jpg, .png] {
            let outputs = try FileConverter.convert(input, to: format)
            XCTAssertEqual(outputs.count, 2)
            for (index, output) in outputs.enumerated() {
                let image = try ImageConverter.decode(output)
                XCTAssertEqual(image.width, index == 0 ? 300 : 200)
                XCTAssertEqual(image.height, index == 0 ? 200 : 300)
                try assertCorners(image, rotation: index == 0 ? 0 : 90)
            }
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testPartialRedactionCoversItsAreaAndPreservesOtherContent() throws {
        let source = try document(text: true)
        XCTAssertTrue(try XCTUnwrap(source.page(at: 0)?.string).contains("SECRET"))
        let bar = Annotation(kind: .redaction, frame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        let data = try AnnotationRenderer.render([bar], into: source)
        let result = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(result.page(at: 0))
        XCTAssertFalse((page.string ?? "").contains("SECRET"))
        let image = try FileConverter.render(page, dpi: 72)
        try assertPixel(image, x: 0.25, y: 0.25, color: RGB(0, 0, 0))
        for (x, y, color) in [(0.92, 0.08, yellow), (0.08, 0.92, red), (0.92, 0.92, green)] {
            try assertPixel(image, x: x, y: y, color: color)
        }
    }
}
