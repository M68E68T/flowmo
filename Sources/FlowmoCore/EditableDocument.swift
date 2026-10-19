import AppKit
import PDFKit
import Vision

/// An immutable copy: neither undo nor a background export may retain the live
/// NSTextStorage. All supported attribute values are immutable as well.
public struct DocumentSnapshot: Equatable, @unchecked Sendable {
    public let text: NSAttributedString
    public let selection: NSRange
    public init(_ text: NSAttributedString, selection: NSRange = NSRange(location: 0, length: 0)) {
        let frozen = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let style = value as? NSParagraphStyle { frozen.addAttribute(.paragraphStyle, value: style.copy(), range: range) }
        }
        self.text = NSAttributedString(attributedString: frozen)
        self.selection = selection
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.text.isEqual(to: rhs.text) }
    public var isEmpty: Bool { text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

public struct DocumentImportResult: @unchecked Sendable {
    public let document: DocumentSnapshot
    public let usedOCR: Bool
}

public enum DocumentImporter {
    public static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont(name: "Helvetica", size: 12)!, .foregroundColor: NSColor.black]
    }

    /// Synchronous worker API. The UI supplies Task.isCancelled and reports
    /// progress on MainActor; this function never writes a file.
    public static func read(_ url: URL, progress: (Int, Int) -> Void = { _, _ in },
                            isCancelled: () -> Bool = { false }) throws -> DocumentImportResult {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        func check() throws { if isCancelled() { throw CancellationError() } }
        try check()
        let content = NSMutableAttributedString(string: "")
        var usedOCR = false
        switch FileKind.detect(url) {
        case .pdf:
            let document = try FileConverter.pdf(url)
            for index in 0..<document.pageCount {
                try check(); progress(index, document.pageCount)
                guard let page = document.page(at: index) else { throw ConversionError.unreadable }
                let text: NSAttributedString
                if let existing = page.attributedString,
                   !existing.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = reflow(page, fallback: existing)
                } else {
                    text = try recognize(FileConverter.render(page), isCancelled: isCancelled)
                    usedOCR = true
                }
                if content.length > 0 { content.append(NSAttributedString(string: "\n\n", attributes: defaultAttributes)) }
                content.append(text)
                progress(index + 1, document.pageCount)
            }
        case .image:
            progress(0, 1)
            content.append(try recognize(ImageConverter.decode(url), isCancelled: isCancelled))
            usedOCR = true; progress(1, 1)
        case .document:
            progress(0, 1)
            if ["txt", "md"].contains(url.pathExtension.lowercased()) {
                content.append(NSAttributedString(string: try String(contentsOf: url, encoding: .utf8), attributes: defaultAttributes))
            } else {
                content.append(try NSAttributedString(url: url, options: [:], documentAttributes: nil))
            }
            progress(1, 1)
        case .unknown: throw ConversionError.unreadable
        }
        try check()
        let result = DocumentSnapshot(sanitized(content))
        guard !result.isEmpty else { throw ConversionError.noText }
        return DocumentImportResult(document: result, usedOCR: usedOCR)
    }

    /// Keep basic text formatting, but never import images, table geometry or
    /// display-dependent system fonts into this deliberately text-only view.
    public static func sanitized(_ input: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(string: input.string, attributes: defaultAttributes)
        let full = NSRange(location: 0, length: input.length)
        input.enumerateAttributes(in: full) { attributes, range, _ in
            if let font = attributes[.font] as? NSFont {
                var portable = font
                if font.fontName.hasPrefix(".") {
                    portable = NSFont(name: "Helvetica", size: font.pointSize)!
                    for trait in [NSFontTraitMask.boldFontMask, .italicFontMask] where NSFontManager.shared.traits(of: font).contains(trait) {
                        portable = NSFontManager.shared.convert(portable, toHaveTrait: trait)
                    }
                }
                result.addAttribute(.font, value: portable, range: range)
            }
            if let color = attributes[.foregroundColor] as? NSColor {
                result.addAttribute(.foregroundColor, value: color, range: range)
            }
            if let underline = attributes[.underlineStyle] { result.addAttribute(.underlineStyle, value: underline, range: range) }
            if let style = attributes[.paragraphStyle] as? NSParagraphStyle,
               let copy = style.mutableCopy() as? NSMutableParagraphStyle {
                copy.textBlocks = []
                result.addAttribute(.paragraphStyle, value: copy.copy() as! NSParagraphStyle, range: range)
            }
        }
        result.mutableString.replaceOccurrences(of: "\u{FFFC}", with: "", options: [], range: NSRange(location: 0, length: result.length))
        return NSAttributedString(attributedString: result)
    }

    private static func reflow(_ page: PDFPage, fallback: NSAttributedString) -> NSAttributedString {
        guard let selection = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters)) else { return fallback }
        let lines = selection.selectionsByLine()
        guard !lines.isEmpty else { return fallback }
        let result = NSMutableAttributedString(string: "")
        let maximumWidth = lines.map { $0.bounds(for: page).width }.max() ?? 0
        var previous: PDFSelection?
        for line in lines {
            guard let text = line.attributedString, text.length > 0 else { continue }
            if let previous {
                let a = previous.bounds(for: page), b = line.bounds(for: page)
                let paragraph = a.width < maximumWidth * 0.75 || a.minY - b.maxY > max(a.height, b.height) * 0.8
                    || abs(a.minX - b.minX) > max(a.height, b.height) * 2
                result.append(NSAttributedString(string: paragraph ? "\n" : " ", attributes: defaultAttributes))
            }
            let range = (text.string as NSString).rangeOfCharacter(from: .newlines, options: .backwards)
            let end = range.location == text.length - 1 ? range.location : text.length
            result.append(text.attributedSubstring(from: NSRange(location: 0, length: end)))
            previous = line
        }
        return result.length > 0 ? result : fallback
    }

    private static func recognize(_ image: CGImage, isCancelled: () -> Bool) throws -> NSAttributedString {
        if isCancelled() { throw CancellationError() }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US", "tr-TR"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        if isCancelled() { throw CancellationError() }
        let lines = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > min($0.boundingBox.height, $1.boundingBox.height) / 2
                ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        var text = "", previous: VNRecognizedTextObservation?
        for line in lines {
            guard let value = line.topCandidates(1).first?.string, !value.isEmpty else { continue }
            if let previous {
                let a = previous.boundingBox, b = line.boundingBox
                let paragraph = a.minY - b.maxY > max(a.height, b.height) * 0.8
                    || abs(a.minX - b.minX) > max(a.height, b.height) * 2 || abs(a.midY - b.midY) < min(a.height, b.height) / 2
                text += paragraph ? "\n" : " "
            }
            text += value; previous = line
        }
        // A blank page in a mixed PDF is valid; the whole document is checked
        // for empty content after all its pages have been processed.
        return NSAttributedString(string: text, attributes: defaultAttributes)
    }
}

/// Shared TextKit 1 geometry for editable pages and PDF glyph drawing. A UI
/// layout belongs to MainActor; an export creates its own isolated instance.
public final class DocumentLayout {
    public static let paper = CGSize(width: 595, height: 842)
    public static let margin: CGFloat = 48
    public static let textSize = CGSize(width: 499, height: 746)
    public let storage: NSTextStorage
    public let manager: NSLayoutManager
    public private(set) var containers: [NSTextContainer] = []

    public init(_ document: DocumentSnapshot) throws {
        storage = NSTextStorage(attributedString: document.text)
        manager = NSLayoutManager()
        manager.backgroundLayoutEnabled = false
        storage.addLayoutManager(manager)
        try paginate()
    }

    public func paginate() throws {
        var index = 0, end = 0
        repeat {
            if index == containers.count {
                let container = NSTextContainer(size: Self.textSize)
                container.lineFragmentPadding = 0
                containers.append(container); manager.addTextContainer(container)
            }
            let container = containers[index]
            manager.ensureLayout(for: container)
            let range = manager.glyphRange(for: container)
            if range.length == 0 && end < manager.numberOfGlyphs { throw ConversionError.tooLarge }
            end = NSMaxRange(range); index += 1
        } while end < manager.numberOfGlyphs || (storage.string.hasSuffix("\n") && manager.extraLineFragmentTextContainer !== containers[index - 1])
        while containers.count > index {
            manager.removeTextContainer(at: containers.count - 1); containers.removeLast()
        }
    }

    public func pdfData() throws -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: Self.paper)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw ConversionError.encoding }
        for container in containers {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(box)
            context.saveGState()
            context.translateBy(x: 0, y: Self.paper.height); context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let range = manager.glyphRange(for: container)
            let origin = CGPoint(x: Self.margin, y: Self.margin)
            manager.drawBackground(forGlyphRange: range, at: origin)
            manager.drawGlyphs(forGlyphRange: range, at: origin)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState(); context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}

public enum DocumentExporter {
    public static func data(_ document: DocumentSnapshot, as format: OutputFormat) throws -> Data {
        guard !document.isEmpty else { throw ConversionError.noText }
        switch format {
        case .pdf: return try DocumentLayout(document).pdfData()
        case .docx:
            return try document.text.data(from: NSRange(location: 0, length: document.text.length), documentAttributes: [
                .documentType: NSAttributedString.DocumentType.officeOpenXML, .paperSize: DocumentLayout.paper,
                .leftMargin: DocumentLayout.margin, .rightMargin: DocumentLayout.margin,
                .topMargin: DocumentLayout.margin, .bottomMargin: DocumentLayout.margin])
        default: throw ConversionError.unsupportedOutput
        }
    }
    public static func write(_ document: DocumentSnapshot, as format: OutputFormat, beside input: URL) throws -> URL {
        try OutputWriter.write(data(document, as: format), beside: input, suffix: "edited", extension: format.fileExtension)
    }
}
