import Foundation
import CoreGraphics
import CoreText
import PDFKit

public enum AnnotationRenderer {
    /// Draws every annotation into a context whose coordinate space is `bounds`
    /// with a bottom-left origin. Shared by the image and the PDF path.
    public static func draw(_ annotations: [Annotation], in context: CGContext,
                            bounds: CGRect, signatures: [String: CGImage] = [:], logicalSize: CGSize? = nil) {
        // Preview and export use the same source coordinates, including fonts
        // and strokes. Only the preview's context is scaled to its display size.
        if let size = logicalSize, size.width > 0, size.height > 0 {
            context.saveGState()
            context.translateBy(x: bounds.minX, y: bounds.minY)
            context.scaleBy(x: bounds.width / size.width, y: bounds.height / size.height)
            draw(annotations, in: context, bounds: CGRect(origin: .zero, size: size), signatures: signatures)
            context.restoreGState()
            return
        }
        let available = Set(signatures.keys)
        for annotation in annotations {
            // One place for the rule, shared by the image and the PDF path.
            guard annotation.isComplete(signatures: available) else { continue }
            let rect = annotation.rect(in: bounds)
            if annotation.kind == .arrow {
                guard rect.width > 0 || rect.height > 0 else { continue }
            } else if rect.width <= 0 || rect.height <= 0 { continue }
            context.saveGState()
            if annotation.rotation != 0 {
                context.translateBy(x: rect.midX, y: rect.midY)
                context.rotate(by: annotation.rotation * .pi / 180)
                context.translateBy(x: -rect.midX, y: -rect.midY)
            }
            switch annotation.kind {
            case .text(let string): drawText(string, in: rect, style: annotation.style, context: context)
            case .signature(let id):
                if let image = signatures[id] { context.interpolationQuality = .high; context.draw(image, in: rect) }
            case .rectangle:
                context.setStrokeColor(annotation.style.color.cgColor)
                context.setLineWidth(annotation.style.lineWidth)
                context.stroke(rect.insetBy(dx: annotation.style.lineWidth / 2, dy: annotation.style.lineWidth / 2))
            case .arrow: drawArrow(in: rect, flipped: annotation.arrowFlipped,
                                   reversed: annotation.arrowReversed, style: annotation.style, context: context)
            case .highlight:
                // Multiply keeps the text underneath readable.
                context.setBlendMode(.multiply)
                context.setFillColor(annotation.style.color.cgColor.copy(alpha: 0.38) ?? annotation.style.color.cgColor)
                context.fill(rect)
            case .redaction:
                // Opaque by definition. The page is rasterized separately so the
                // covered text is gone, not merely hidden.
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(rect)
            }
            context.restoreGState()
        }
    }

    private static func drawText(_ string: String, in rect: CGRect, style: AnnotationStyle, context: CGContext) {
        guard !string.isEmpty else { return }
        let font = CTFontCreateWithName("Helvetica" as CFString, style.fontSize, nil)
        let attributed = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: style.color.cgColor
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0),
                                             CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, context)
    }

    private static func drawArrow(in rect: CGRect, flipped: Bool, reversed: Bool, style: AnnotationStyle, context: CGContext) {
        let (start, end) = AnnotationGeometry.arrowPoints(in: rect, flipped: flipped, reversed: reversed)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = min(max(8, style.lineWidth * 5), hypot(end.x - start.x, end.y - start.y) * 0.7)
        context.setStrokeColor(style.color.cgColor)
        context.setFillColor(style.color.cgColor)
        context.setLineWidth(style.lineWidth)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: CGPoint(x: end.x - cos(angle) * head * 0.6, y: end.y - sin(angle) * head * 0.6))
        context.strokePath()
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x - cos(angle - .pi / 7) * head, y: end.y - sin(angle - .pi / 7) * head))
        context.addLine(to: CGPoint(x: end.x - cos(angle + .pi / 7) * head, y: end.y - sin(angle + .pi / 7) * head))
        context.closePath()
        context.fillPath()
    }

    /// Images have no text layer, so drawing is always enough.
    public static func render(_ annotations: [Annotation], on image: CGImage,
                              signatures: [String: CGImage] = [:]) throws -> CGImage {
        let context = try ImageTools.canvas(image.width, image.height)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        draw(annotations.on(page: 0), in: context, bounds: bounds, signatures: signatures)
        guard let result = context.makeImage() else { throw ConversionError.encoding }
        return result
    }

    /// Per page one of two routes:
    /// - no redaction: the original page is drawn through, so text stays sharp,
    ///   selectable and searchable;
    /// - with redaction: the page is rasterized first and the bar painted onto
    ///   the pixels, which physically removes the covered text.
    public static func render(_ annotations: [Annotation], into document: PDFDocument,
                              signatures: [String: CGImage] = [:],
                              redactionDPI: Double = 200) throws -> Data {
        guard document.pageCount > 0 else { throw ConversionError.unreadable }
        let data = NSMutableData()
        var firstBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else { throw ConversionError.encoding }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let ref = page.pageRef else { throw ConversionError.unreadable }
            let raw = page.bounds(for: .mediaBox)
            let turned = page.rotation % 180 != 0
            // Rotation is baked in: the exported page is upright.
            var box = CGRect(x: 0, y: 0, width: turned ? raw.height : raw.width, height: turned ? raw.width : raw.height)
            context.beginPage(mediaBox: &box)
            if annotations.requiresRasterizing(page: index) {
                let raster = try FileConverter.render(page, dpi: redactionDPI)
                context.interpolationQuality = .high
                context.draw(raster, in: box)
            } else {
                context.saveGState()
                context.concatenate(ref.getDrawingTransform(.mediaBox, rect: box, rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(ref)
                context.restoreGState()
            }
            draw(annotations.on(page: index), in: context, bounds: box, signatures: signatures)
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }
}
