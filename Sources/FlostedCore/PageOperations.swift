import Foundation
import AppKit
import PDFKit

/// Plain PDFKit page handling, free of UI so it stays testable.
/// Every function works on a copy; the caller owns the document it passes in.
public enum PageOperations {
    /// Rotation is stored in degrees and PDFKit expects multiples of 90.
    /// Normalized to 0...270 so repeated turns never run away.
    /// Takes the pages themselves: a caller that has reordered or removed pages
    /// no longer has indices matching the original document.
    public static func rotate(_ pages: [PDFPage], by degrees: Int) {
        let step = ((degrees / 90) % 4) * 90
        for page in pages {
            var value = (page.rotation + step) % 360
            if value < 0 { value += 360 }
            page.rotation = value
        }
    }
    public static func rotate(_ document: PDFDocument, pages: IndexSet, by degrees: Int) {
        rotate(pages.compactMap { document.page(at: $0) }, by: degrees)
    }

    /// Removing every page would leave an invalid document, so that is refused.
    public static func delete(_ document: PDFDocument, pages: IndexSet) throws {
        let valid = pages.filter { $0 >= 0 && $0 < document.pageCount }
        guard !valid.isEmpty else { return }
        guard valid.count < document.pageCount else { throw ConversionError.unsupportedOutput }
        // Descending, otherwise the remaining indices shift underneath us.
        for index in valid.sorted(by: >) { document.removePage(at: index) }
    }

    public static func move(_ document: PDFDocument, from: Int, to: Int) {
        guard from >= 0, from < document.pageCount, to >= 0, to < document.pageCount, from != to,
              let page = document.page(at: from) else { return }
        document.removePage(at: from)
        document.insert(page, at: min(to, document.pageCount))
    }

    /// Pages belong to their document, so each one is copied before inserting.
    public static func append(_ document: PDFDocument, contentsOf other: PDFDocument) {
        for index in 0..<other.pageCount {
            guard let page = other.page(at: index)?.copy() as? PDFPage else { continue }
            document.insert(page, at: document.pageCount)
        }
    }

    /// Pages for any supported file: every page of a PDF, or a single page
    /// wrapping an image. Throws for anything else.
    public static func pages(from url: URL, maximumEdge: Int = 2400) throws -> [PDFPage] {
        switch FileKind.detect(url) {
        case .pdf:
            let document = try FileConverter.pdf(url)
            return (0..<document.pageCount).compactMap { document.page(at: $0)?.copy() as? PDFPage }
        case .image:
            var image = try ImageConverter.decode(url)
            // Without this a phone photo would become a page metres across,
            // because PDFPage maps one pixel to one point.
            let longest = max(image.width, image.height)
            if longest > maximumEdge {
                image = try ImageTools.resize(image, scale: Double(maximumEdge) / Double(longest))
            }
            let size = CGSize(width: image.width, height: image.height)
            guard let page = PDFPage(image: NSImage(cgImage: image, size: size)) else {
                throw ConversionError.encoding
            }
            return [page]
        case .document, .unknown:
            throw ConversionError.unreadable
        }
    }

    public static func data(_ document: PDFDocument) throws -> Data {
        guard document.pageCount > 0, let data = document.dataRepresentation() else { throw ConversionError.encoding }
        return data
    }
}
