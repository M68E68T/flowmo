import Foundation
import AppKit
import PDFKit
import CoreText
import Vision

public enum FileConverter {
    public static func convert(_ input: URL, to format: OutputFormat) throws -> [URL] {
        let access = input.startAccessingSecurityScopedResource()
        defer { if access { input.stopAccessingSecurityScopedResource() } }
        switch FileKind.detect(input) {
        case .image:
            if format.isRaster { return [try ImageConverter.convert(input, to: format)] }
            let image = try ImageConverter.decode(input)
            if format == .pdf {
                guard let page = PDFPage(image: NSImage(cgImage: image, size: .zero)) else { throw ConversionError.encoding }
                let doc = PDFDocument(); doc.insert(page, at: 0)
                guard let data = doc.dataRepresentation() else { throw ConversionError.encoding }
                return [try OutputWriter.write(data, beside: input, extension: "pdf")]
            }
            return [try writeText(NSAttributedString(string: recognizedText(image)), beside: input, as: format)]
        case .pdf:
            let doc = try pdf(input)
            if format.isRaster {
                var outputs: [URL] = []
                for index in 0..<doc.pageCount {
                    let image = try render(try requiredPage(doc, index), dpi: 150)
                    outputs.append(try OutputWriter.write(ImageConverter.encode(image, as: format), beside: input,
                        suffix: String(format: "page-%03d", index + 1), extension: format.fileExtension))
                }
                return outputs
            }
            let text = NSMutableAttributedString(string: "")
            for index in 0..<doc.pageCount {
                let page = try requiredPage(doc, index)
                if index > 0 { text.append(NSAttributedString(string: "\n\u{000C}\n")) }
                if let attributed = page.attributedString, !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text.append(attributed)
                } else { text.append(NSAttributedString(string: try recognizedText(render(page, dpi: 150)))) }
            }
            guard !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ConversionError.noText }
            return [try writeText(text, beside: input, as: format)]
        case .document:
            let text: NSAttributedString
            if ["txt", "md"].contains(input.pathExtension.lowercased()) {
                text = NSAttributedString(string: try String(contentsOf: input, encoding: .utf8), attributes: [.font: NSFont(name: "Helvetica", size: 12)!])
            } else { text = try NSAttributedString(url: input, options: [:], documentAttributes: nil) }
            return [try writeText(text, beside: input, as: format)]
        case .unknown: throw ConversionError.unreadable
        }
    }
    public static func pdf(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else { throw ConversionError.unreadable }
        guard !doc.isLocked else { throw ConversionError.lockedPDF }
        guard doc.pageCount > 0 else { throw ConversionError.unreadable }; return doc
    }
    private static func requiredPage(_ doc: PDFDocument, _ index: Int) throws -> PDFPage {
        guard let page = doc.page(at: index) else { throw ConversionError.unreadable }; return page
    }
    public static func render(_ page: PDFPage, dpi: Double = 150) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let rotated = page.rotation % 180 != 0
        let size = CGSize(width: rotated ? bounds.height : bounds.width, height: rotated ? bounds.width : bounds.height)
        let width = Int(ceil(size.width * dpi / 72)), height = Int(ceil(size.height * dpi / 72))
        guard width > 0, height > 0, Double(width) * Double(height) <= 100_000_000 else { throw ConversionError.tooLarge }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let ref = page.pageRef else { throw ConversionError.encoding }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect)
        // getDrawingTransform can shrink a page, but does not upscale it to
        // the raster's DPI. Map PDF points to pixels explicitly, including
        // clockwise page rotation and a media box whose origin is not zero.
        let turn = CGAffineTransform(rotationAngle: -CGFloat(page.rotation % 360) * .pi / 180)
        let turnedBounds = bounds.applying(turn)
        let scale = dpi / 72
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -turnedBounds.minX, y: -turnedBounds.minY)
        context.concatenate(turn)
        context.drawPDFPage(ref)
        guard let result = context.makeImage() else { throw ConversionError.encoding }; return result
    }
    private static func recognizedText(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US", "tr-TR"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        guard !text.isEmpty else { throw ConversionError.noText }; return text
    }
    private static func writeText(_ text: NSAttributedString, beside input: URL, as format: OutputFormat) throws -> URL {
        let data: Data
        switch format {
        case .txt: data = Data(text.string.utf8)
        case .docx:
            let portable = NSMutableAttributedString(attributedString: text)
            portable.enumerateAttribute(.font, in: NSRange(location: 0, length: portable.length)) { value, range, _ in
                if let font = value as? NSFont, font.fontName.hasPrefix(".") {
                    var substitute = NSFont(name: "Helvetica", size: font.pointSize)!
                    let traits = NSFontManager.shared.traits(of: font)
                    if traits.contains(.boldFontMask) { substitute = NSFontManager.shared.convert(substitute, toHaveTrait: .boldFontMask) }
                    if traits.contains(.italicFontMask) { substitute = NSFontManager.shared.convert(substitute, toHaveTrait: .italicFontMask) }
                    portable.addAttribute(.font, value: substitute, range: range)
                }
            }
            data = try portable.data(from: NSRange(location: 0, length: portable.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        case .pdf: data = try documentPDF(text)
        default: throw ConversionError.unsupportedOutput
        }
        return try OutputWriter.write(data, beside: input, extension: format.fileExtension)
    }
    private static func documentPDF(_ text: NSAttributedString) throws -> Data {
        let content = NSMutableAttributedString(attributedString: text)
        if content.length == 0 { content.append(NSAttributedString(string: " ")) }
        content.enumerateAttribute(.font, in: NSRange(location: 0, length: content.length)) { value, range, _ in
            if value == nil { content.addAttribute(.font, value: NSFont(name: "Helvetica", size: 12)!, range: range) }
        }
        let data = NSMutableData(); var media = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { throw ConversionError.encoding }
        let framesetter = CTFramesetterCreateWithAttributedString(content)
        let path = CGPath(rect: media.insetBy(dx: 48, dy: 48), transform: nil)
        var offset = 0
        while offset < content.length {
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            let range = CTFrameGetVisibleStringRange(frame)
            guard range.length > 0 else { throw ConversionError.encoding }
            context.beginPDFPage(nil); CTFrameDraw(frame, context); context.endPDFPage(); offset += range.length
        }
        context.closePDF(); return data as Data
    }
}
