import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FlostedCore

final class ImageConverterTests: XCTestCase {
    func testConversionPreservesOriginalAndExistingOutput() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("sample.png")
        let context = try XCTUnwrap(CGContext(data: nil, width: 24, height: 16, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0.4, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(input as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = try Data(contentsOf: input)
        for format in [OutputFormat.png, .jpg, .tiff] {
            let first = try ImageConverter.convert(input, to: format)
            let saved = try Data(contentsOf: first)
            let second = try ImageConverter.convert(input, to: format)
            XCTAssertNotEqual(first, second)
            XCTAssertEqual(try Data(contentsOf: first), saved)
            let convertedSource = try XCTUnwrap(CGImageSourceCreateWithURL(first as CFURL, nil))
            let converted = try XCTUnwrap(CGImageSourceCreateImageAtIndex(convertedSource, 0, nil))
            XCTAssertEqual(converted.width, 24)
            XCTAssertEqual(converted.height, 16)
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testInvalidInputDoesNotCreateAnOutput() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: input)
        XCTAssertThrowsError(try ImageConverter.convert(input, to: .jpg))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["invalid.png"])
    }
}
