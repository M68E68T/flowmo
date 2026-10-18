import XCTest
import CoreGraphics
import ImageIO
@testable import FlostedCore

final class UXRegressionTests: XCTestCase {
    func testCancelExistingTextPreservesContentAndOtherElements() {
        let text = Annotation(kind: .text("Bleibt erhalten"), frame: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2))
        let other = Annotation(kind: .signature(id: "signature"), frame: .zero)
        let original = [text, other]
        XCTAssertEqual(AnnotationEdits.text(original, id: text.id, value: nil, committed: original), original)
        // A dialog must not turn the other selected element into text.
        XCTAssertEqual(AnnotationEdits.text(original, id: other.id, value: "wrong", committed: original), original)
    }

    func testTextCreationAndCancellationAreSingleUndoTransactions() {
        let draft = Annotation(kind: .text(""), frame: CGRect(x: 0, y: 0, width: 1, height: 0.2))
        var history = UndoStack<[Annotation]>([])
        let cancelled = AnnotationEdits.text([draft], id: draft.id, value: nil, committed: history.current)
        history.commitIfChanged(cancelled)
        XCTAssertTrue(cancelled.isEmpty)
        XCTAssertFalse(history.canUndo, "An abgebrochener Rahmen darf nie im Undo-Verlauf stehen.")
        let finished = AnnotationEdits.text([draft], id: draft.id, value: "Hallo", committed: history.current)
        history.commitIfChanged(finished)
        history.commitIfChanged(finished) // selection without a modification
        XCTAssertEqual(history.undo(), [])
        XCTAssertFalse(history.canUndo)
        XCTAssertEqual(history.redo(), finished)
        XCTAssertTrue(finished.allSatisfy { $0.isComplete(signatures: []) })
    }

    func testCropEveryHandleKeepsOppositePointAndStaysInsideImage() {
        let bounds = CGRect(x: 10, y: 20, width: 600, height: 400)
        let rect = CGRect(x: 100, y: 100, width: 200, height: 120)
        for handle in CropHandle.allCases {
            XCTAssertEqual(CropGeometry.handle(at: handle.point(in: rect), in: rect), handle)
            let anchor = handle.opposite.point(in: rect)
            let target = handle.point(in: rect)
            let point = CGPoint(x: target.x + (target.x < anchor.x ? -40 : 40),
                                y: target.y + (target.y < anchor.y ? -30 : 30))
            let resized = CropGeometry.resize(rect, handle: handle, to: point, in: bounds)
            XCTAssertEqual(handle.opposite.point(in: resized), anchor, "\(handle)")
            XCTAssertTrue(bounds.contains(resized), "\(handle)")
        }
        let moved = CropGeometry.move(rect, by: CGSize(width: -1000, height: 1000), in: bounds)
        XCTAssertEqual(moved.minX, bounds.minX)
        XCTAssertEqual(moved.maxY, bounds.maxY)
        XCTAssertEqual(moved.size, rect.size)
    }

    func testCropRatioAndBoundsSurviveCornerAndEdgeResize() {
        let bounds = CGRect(x: 0, y: 0, width: 640, height: 480)
        let rect = CGRect(x: 160, y: 120, width: 320, height: 240)
        for handle in CropHandle.allCases {
            let point = handle.point(in: rect)
            let stretched = CGPoint(x: point.x < rect.midX ? -200 : 900,
                                    y: point.y < rect.midY ? -200 : 900)
            let result = CropGeometry.resize(rect, handle: handle, to: stretched, in: bounds, ratio: 4.0 / 3)
            XCTAssertEqual(result.width / result.height, 4.0 / 3, accuracy: 0.0001)
            XCTAssertTrue(bounds.insetBy(dx: -0.001, dy: -0.001).contains(result))
            XCTAssertEqual(handle.opposite.point(in: result), handle.opposite.point(in: rect))
        }
    }

    func testTextAndStrokesScaleWithPreviewRatherThanChangingRelativeSize() throws {
        func ink(_ side: Int) throws -> CGSize {
            let context = try ImageTools.canvas(side, side)
            let note = Annotation(kind: .text("MMMM"), frame: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                                  style: AnnotationStyle(fontSize: 32))
            AnnotationRenderer.draw([note], in: context, bounds: CGRect(x: 0, y: 0, width: side, height: side),
                                    logicalSize: CGSize(width: 400, height: 400))
            let bytes = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * side)
            var minX = side, minY = side, maxX = 0, maxY = 0
            for y in 0..<side { for x in 0..<side where bytes[y * context.bytesPerRow + x * 4 + 3] > 32 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            } }
            return CGSize(width: maxX - minX + 1, height: maxY - minY + 1)
        }
        let small = try ink(400), large = try ink(800)
        XCTAssertEqual(large.width, small.width * 2, accuracy: 3)
        XCTAssertEqual(large.height, small.height * 2, accuracy: 3)
    }

    func testCompressionPreviewBytesMatchExportAndHonorLimit() throws {
        let context = try ImageTools.canvas(400, 300)
        // A deterministic textured image forces the quality search to do work.
        let bytes = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * 300)
        for y in 0..<300 { for x in 0..<400 {
            let i = y * context.bytesPerRow + x * 4
            bytes[i] = UInt8((x * 31 + y * 17) % 256); bytes[i + 1] = UInt8((x * 11 + y * 37) % 256)
            bytes[i + 2] = UInt8((x * 53 + y * 3) % 256); bytes[i + 3] = 255
        } }
        let image = try XCTUnwrap(context.makeImage())
        let plain = try JPEGCompression.encode(image, quality: 0.9)
        let minimum = try JPEGCompression.encode(image, quality: 0.05)
        XCTAssertGreaterThan(plain.data.count, minimum.data.count)
        let limit = (plain.data.count + minimum.data.count) / 2
        let preview = try JPEGCompression.encode(image, quality: 0.9, targetBytes: limit)
        let saved = try JPEGCompression.encode(image, quality: 0.9, targetBytes: limit)
        XCTAssertEqual(preview.data, saved.data)
        XCTAssertLessThanOrEqual(saved.data.count, limit)
        XCTAssertLessThan(saved.quality, 0.9)
        XCTAssertNotNil(CGImageSourceCreateWithData(saved.data as CFData, nil))
        XCTAssertThrowsError(try JPEGCompression.encode(image, quality: 0.9, targetBytes: 1)) { error in
            guard case ConversionError.sizeLimit = error else { return XCTFail("\(error)") }
        }
    }

    func testCorruptImageIsUnreadableInsteadOfAnimated() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try Data("not an image".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try ImageConverter.decode(file)) { error in
            guard case ConversionError.unreadable = error else { return XCTFail("\(error)") }
        }
    }
}
