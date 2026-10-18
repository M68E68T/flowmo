import Foundation
import CoreGraphics

public enum AnnotationKind: Equatable, Sendable {
    case text(String)
    case signature(id: String)
    case arrow, rectangle, highlight, redaction

    /// Redaction is the only kind that must physically remove page content.
    public var removesContent: Bool { self == .redaction }
}

public struct AnnotationStyle: Equatable, Sendable {
    public var color: RGB
    public var fontSize: Double
    public var lineWidth: Double
    public init(color: RGB = RGB(0.87, 0.23, 0.015), fontSize: Double = 14, lineWidth: Double = 2) {
        self.color = color
        self.fontSize = max(4, fontSize)
        self.lineWidth = max(0.5, lineWidth)
    }
}

/// Position normalized 0...1 against the page or image, bottom-left origin —
/// the same convention ImageTools.crop(selection:) already uses. Normalized
/// coordinates keep an annotation in place no matter the render resolution.
public struct Annotation: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var kind: AnnotationKind
    public var frame: CGRect
    public var style: AnnotationStyle
    public var page: Int
    public var rotation: Double
    /// Which diagonal of the frame an arrow follows. Keeping the model on a
    /// rectangle while still covering all four directions.
    public var arrowFlipped: Bool

    public init(id: UUID = UUID(), kind: AnnotationKind, frame: CGRect,
                style: AnnotationStyle = AnnotationStyle(), page: Int = 0,
                rotation: Double = 0, arrowFlipped: Bool = false) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.style = style
        self.page = max(0, page)
        self.rotation = rotation
        self.arrowFlipped = arrowFlipped
    }

    /// Maps the normalized frame onto a concrete canvas, flipping nothing:
    /// both the stored frame and CGContext use a bottom-left origin.
    public func rect(in bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + frame.minX * bounds.width,
               y: bounds.minY + frame.minY * bounds.height,
               width: frame.width * bounds.width,
               height: frame.height * bounds.height).standardized
    }
}

public extension Annotation {
    /// False when there is nothing to draw: empty text, or a signature whose
    /// image is not available. Such elements must never reach the output —
    /// otherwise saving produces a file that looks exactly like the original.
    func isComplete(signatures: Set<String>) -> Bool {
        switch kind {
        case .text(let value): return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .signature(let id): return signatures.contains(id)
        case .arrow, .rectangle, .highlight, .redaction: return true
        }
    }
}

public extension Array where Element == Annotation {
    func complete(signatures: Set<String>) -> [Annotation] {
        filter { $0.isComplete(signatures: signatures) }
    }
    func on(page index: Int) -> [Annotation] { filter { $0.page == index } }

    /// True when drawing over the original page is not enough. Text under a
    /// black bar stays selectable and extractable, so such a page has to be
    /// rasterized instead — see AnnotationRenderer.
    func requiresRasterizing(page index: Int) -> Bool {
        on(page: index).contains { $0.kind.removesContent }
    }
}
