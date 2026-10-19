import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public enum OutputFormat: String, CaseIterable, Sendable {
    case png = "PNG", jpg = "JPG", heic = "HEIC", tiff = "TIFF", bmp = "BMP"
    case pdf = "PDF", txt = "TXT", docx = "DOCX"
    public var fileExtension: String { rawValue.lowercased() }
    public var type: UTType {
        switch self {
        case .png: return .png
        case .jpg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .pdf: return .pdf
        case .txt: return .plainText
        case .docx: return UTType(filenameExtension: "docx")!
        }
    }
    public var isRaster: Bool { ![.pdf, .txt, .docx].contains(self) }
    public var encoderAvailable: Bool {
        !isRaster || (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains(type.identifier)
    }
}

public enum ConversionError: LocalizedError {
    case unreadable, animatedImage, unsupportedOutput, encoding, lockedPDF, noText, tooLarge, sizeLimit
    /// Resolved against Bundle.main, which is the app at runtime. In tests the
    /// key itself comes back; the tests assert on cases, not on wording.
    public var errorDescription: String? {
        let key: String
        switch self {
        case .unreadable: key = "error.unreadable"
        case .animatedImage: key = "error.animatedImage"
        case .unsupportedOutput: key = "error.unsupportedOutput"
        case .encoding: key = "error.encoding"
        case .lockedPDF: key = "error.lockedPDF"
        case .noText: key = "error.noText"
        case .tooLarge: key = "error.tooLarge"
        case .sizeLimit: key = "error.sizeLimit"
        }
        return NSLocalizedString(key, bundle: .main, comment: "")
    }
}

public enum OutputWriter {
    public static func write(_ data: Data, beside input: URL, suffix: String = "converted", extension ext: String) throws -> URL {
        let stem = input.deletingPathExtension().lastPathComponent + "-" + suffix
        let folder = input.deletingLastPathComponent()
        for index in 0..<10_000 {
            let number = index == 0 ? "" : "-\(index)"
            let url = folder.appendingPathComponent("\(stem)\(number).\(ext)")
            do { try data.write(to: url, options: .withoutOverwriting); return url }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
        }
        throw ConversionError.encoding
    }
}

public enum ImageConverter {
    public static func decode(_ input: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else { throw ConversionError.unreadable }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw ConversionError.unreadable }
        guard count == 1 else { throw ConversionError.animatedImage }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        let width = props?[kCGImagePropertyPixelWidth as String] as? Int ?? 1
        let height = props?[kCGImagePropertyPixelHeight as String] as? Int ?? 1
        guard width > 0, height > 0, Double(width) * Double(height) <= 100_000_000 else { throw ConversionError.tooLarge }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(width, height)]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ConversionError.unreadable }
        return image
    }
    public static func encode(_ image: CGImage, as format: OutputFormat, quality: Double = 0.9) throws -> Data {
        guard format.isRaster, format.encoderAvailable else { throw ConversionError.unsupportedOutput }
        var result = image
        if format == .jpg || format == .bmp {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ConversionError.encoding }
            let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect); context.draw(image, in: rect)
            guard let flattened = context.makeImage() else { throw ConversionError.encoding }; result = flattened
        }
        let data = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else { throw ConversionError.unsupportedOutput }
        CGImageDestinationAddImage(encoder, result, [kCGImageDestinationLossyCompressionQuality: min(1, max(0.05, quality))] as CFDictionary)
        guard CGImageDestinationFinalize(encoder) else { throw ConversionError.encoding }
        return data as Data
    }
    public static func convert(_ input: URL, to format: OutputFormat) throws -> URL {
        let access = input.startAccessingSecurityScopedResource()
        defer { if access { input.stopAccessingSecurityScopedResource() } }
        return try OutputWriter.write(encode(decode(input), as: format), beside: input, extension: format.fileExtension)
    }
}
