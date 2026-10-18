import Foundation
import CoreGraphics

public enum ResizeHandle: CaseIterable, Sendable {
    case bottomLeft, bottomRight, topLeft, topRight

    /// Arrows are dragged by their two ends rather than four corners.
    public static let arrowEnds: [ResizeHandle] = [.bottomLeft, .topRight]

    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
    public var opposite: ResizeHandle {
        switch self {
        case .bottomLeft: return .topRight
        case .bottomRight: return .topLeft
        case .topLeft: return .bottomRight
        case .topRight: return .bottomLeft
        }
    }
}

public enum AnnotationGeometry {
    public static func handle(at point: CGPoint, of rect: CGRect,
                              candidates: [ResizeHandle] = ResizeHandle.allCases,
                              tolerance: CGFloat = 9) -> ResizeHandle? {
        candidates.first { hypot(point.x - $0.point(in: rect).x, point.y - $0.point(in: rect).y) <= tolerance }
    }

    /// Keeps the opposite corner fixed. Dragging past it flips the rectangle
    /// rather than producing a negative size, and `minimum` is always honoured.
    public static func resize(_ rect: CGRect, handle: ResizeHandle, to point: CGPoint,
                              minimum: CGSize = CGSize(width: 12, height: 12)) -> CGRect {
        let anchor = handle.opposite.point(in: rect)
        var width = abs(point.x - anchor.x), height = abs(point.y - anchor.y)
        width = max(width, minimum.width); height = max(height, minimum.height)
        let x = point.x < anchor.x ? anchor.x - width : anchor.x
        let y = point.y < anchor.y ? anchor.y - height : anchor.y
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Frame plus diagonal for an arrow running from `start` to `end`.
    /// `flipped` means top-left to bottom-right instead of bottom-left to top-right.
    public static func arrow(from start: CGPoint, to end: CGPoint) -> (rect: CGRect, flipped: Bool) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        // Flipped when the two points run against the rising diagonal.
        let flipped = (end.x - start.x) * (end.y - start.y) < 0
        return (rect, flipped)
    }

    /// The two ends of an arrow drawn inside `rect`, honouring the diagonal.
    public static func arrowPoints(in rect: CGRect, flipped: Bool) -> (start: CGPoint, end: CGPoint) {
        flipped ? (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY))
                : (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY))
    }
}
