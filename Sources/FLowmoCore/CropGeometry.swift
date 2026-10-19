import Foundation
import CoreGraphics

public enum CropHandle: CaseIterable {
    case bottomLeft, bottom, bottomRight, right, topRight, top, topLeft, left
    public var affectsX: Bool { self != .top && self != .bottom }
    public var affectsY: Bool { self != .left && self != .right }
    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .top: return CGPoint(x: rect.midX, y: rect.maxY)
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
    public var opposite: CropHandle {
        switch self {
        case .bottomLeft: return .topRight
        case .bottom: return .top
        case .bottomRight: return .topLeft
        case .right: return .left
        case .topRight: return .bottomLeft
        case .top: return .bottom
        case .topLeft: return .bottomRight
        case .left: return .right
        }
    }
}

public enum CropGeometry {
    public static func handle(at point: CGPoint, in rect: CGRect, tolerance: Double = 8) -> CropHandle? {
        CropHandle.allCases.first { hypot(point.x - $0.point(in: rect).x, point.y - $0.point(in: rect).y) <= tolerance }
    }

    public static func resize(_ rect: CGRect, handle: CropHandle, to point: CGPoint,
                              in bounds: CGRect, ratio: Double = 0) -> CGRect {
        let anchor = handle.opposite.point(in: rect)
        let sx: CGFloat = point.x < anchor.x ? -1 : 1
        let sy: CGFloat = point.y < anchor.y ? -1 : 1
        var w = handle.affectsX ? max(2, abs(point.x - anchor.x)) : rect.width
        var h = handle.affectsY ? max(2, abs(point.y - anchor.y)) : rect.height
        if ratio > 0 {
            if handle.affectsX && handle.affectsY { w = min(w, h * ratio); h = w / ratio }
            else if handle.affectsX { h = w / ratio }
            else { w = h * ratio }
        }
        let maxW = handle.affectsX ? (sx < 0 ? anchor.x - bounds.minX : bounds.maxX - anchor.x)
            : 2 * min(rect.midX - bounds.minX, bounds.maxX - rect.midX)
        let maxH = handle.affectsY ? (sy < 0 ? anchor.y - bounds.minY : bounds.maxY - anchor.y)
            : 2 * min(rect.midY - bounds.minY, bounds.maxY - rect.midY)
        if ratio > 0 {
            let fit = max(0, min(1, min(maxW / max(w, 0.001), maxH / max(h, 0.001))))
            w *= fit; h *= fit
        } else { w = max(0, min(w, maxW)); h = max(0, min(h, maxH)) }
        return CGRect(x: handle.affectsX ? anchor.x - (sx < 0 ? w : 0) : rect.midX - w / 2,
                      y: handle.affectsY ? anchor.y - (sy < 0 ? h : 0) : rect.midY - h / 2,
                      width: w, height: h)
    }

    public static func move(_ rect: CGRect, by delta: CGSize, in bounds: CGRect) -> CGRect {
        CGRect(x: min(max(rect.minX + delta.width, bounds.minX), bounds.maxX - rect.width),
               y: min(max(rect.minY + delta.height, bounds.minY), bounds.maxY - rect.height),
               width: rect.width, height: rect.height)
    }
}
