import Foundation
import CoreGraphics
import UniformTypeIdentifiers

public enum FileKind: Equatable, Sendable {
    case image, pdf, document, unknown
    public static func detect(_ url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return .pdf }
        if ["txt", "md", "rtf", "docx"].contains(ext) { return .document }
        if UTType(filenameExtension: ext)?.conforms(to: .image) == true { return .image }
        return .unknown
    }
}
public enum FileAction: Hashable, Sendable {
    case convert(OutputFormat), crop, background, compress, annotate, pages
    /// Shown inside the wheel sectors, where space is tight.
    public var title: String {
        let key: String
        switch self {
        case .convert(let format): return format.rawValue
        case .crop: key = "wheel.crop"
        case .background: key = "wheel.background"
        case .compress: key = "wheel.compress"
        case .annotate: key = "wheel.annotate"
        case .pages: key = "wheel.pages"
        }
        return NSLocalizedString(key, bundle: .main, comment: "")
    }
    public var symbol: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"
        case .crop: return "crop"
        case .background: return "rectangle.on.rectangle"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .annotate: return "signature"
        case .pages: return "doc.on.doc"
        }
    }
}
public enum ActionCatalog {
    public static func actions(for urls: [URL], tools: Bool) -> [FileAction] {
        guard let first = urls.first else { return [] }
        let kind = FileKind.detect(first)
        guard urls.allSatisfy({ FileKind.detect($0) == kind }) else { return [] }
        if tools {
            guard urls.count == 1 else { return [] }
            switch kind {
            case .image: return [.crop, .background, .compress, .annotate]
            case .pdf: return [.annotate, .pages]  // edit content, or reorder pages
            case .document, .unknown: return []
            }
        }
        let formats: [OutputFormat]
        switch kind {
        case .pdf: formats = [.docx, .jpg, .png, .txt]
        case .document: formats = [.pdf, .docx, .txt]
        case .image: formats = [.png, .jpg, .heic, .tiff, .bmp, .pdf]
        case .unknown: return []
        }
        return formats.filter(\.encoderAvailable).map(FileAction.convert)
    }
}
public enum RadialGeometry {
    public static func index(point: CGPoint, center: CGPoint, inner: Double, outer: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let distance = hypot(point.x - center.x, point.y - center.y)
        guard distance >= inner, distance <= outer else { return nil }
        let step = 2 * Double.pi / Double(count)
        var angle = self.angle(of: point, around: center) + step / 2
        if angle < 0 { angle += 2 * .pi }
        return Int(angle / step) % count
    }
    /// Clockwise from twelve o'clock, the same way the sectors are counted.
    public static func angle(of point: CGPoint, around center: CGPoint) -> Double {
        atan2(point.x - center.x, point.y - center.y)
    }
    /// Signed change between two pointer angles in (-π, π]; positive is clockwise.
    public static func turn(from previous: Double, to next: Double) -> Double {
        var delta = (next - previous).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta <= -.pi { delta += 2 * .pi }
        return delta
    }
    /// Turns the highlight from sector `previous` to `index` in the direction
    /// the pointer moved, however many sectors that takes, so it always travels
    /// with the hand. Without a direction it falls back to the short way.
    public static func rotation(to index: Int, from previous: Int, count: Int,
                                current: Double, clockwise: Bool?) -> Double {
        guard count > 0, let clockwise else { return rotation(to: index, count: count, from: current) }
        let step = 2 * Double.pi / Double(count)
        let sectors = ((clockwise ? index - previous : previous - index) % count + count) % count
        // AppKit turns counter-clockwise for positive angles.
        return current + (clockwise ? -1 : 1) * Double(sectors) * step
    }
    /// Clockwise angle (radians, AppKit's counter-clockwise positive) that turns
    /// sector 0 onto sector `index`, continued from `current` the short way
    /// round, so the highlight never sweeps across the whole wheel.
    public static func rotation(to index: Int, count: Int, from current: Double) -> Double {
        guard count > 0 else { return current }
        let target = -2 * Double.pi * Double(index) / Double(count)
        var delta = (target - current).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return current + delta
    }
    public static func frame(around point: CGPoint, size: CGSize, in screen: CGRect) -> CGRect {
        let x = min(max(point.x - size.width / 2, screen.minX), max(screen.minX, screen.maxX - size.width))
        let y = min(max(point.y - size.height / 2, screen.minY), max(screen.minY, screen.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
public enum WindowPlacement {
    /// Puts `size` next to `anchor` without covering it, kept inside `screen`.
    /// Prefers the right side, falls back to the left, and only when neither
    /// side fits does it clamp to the screen edge.
    public static func beside(_ anchor: CGRect, size: CGSize,
                              in screen: CGRect, gap: CGFloat = 14) -> CGRect {
        let x: CGFloat
        if anchor.maxX + gap + size.width <= screen.maxX { x = anchor.maxX + gap }
        else if anchor.minX - gap - size.width >= screen.minX { x = anchor.minX - gap - size.width }
        else { x = min(max(anchor.maxX + gap, screen.minX), max(screen.minX, screen.maxX - size.width)) }
        // Top aligned with the anchor, so both windows read as one group.
        let top = anchor.maxY - size.height
        let y = min(max(top, screen.minY), max(screen.minY, screen.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// Like `beside`, but when neither side has room it shifts the anchor
    /// sideways so both still fit next to each other. A wide editor next to the
    /// dashboard otherwise lands on top of it on a 1440-point screen.
    public static func pair(_ anchor: CGRect, size: CGSize, in screen: CGRect,
                            gap: CGFloat = 14) -> (anchor: CGRect, window: CGRect) {
        let frame = beside(anchor, size: size, in: screen, gap: gap)
        let total = anchor.width + gap + size.width
        guard frame.intersects(anchor), total <= screen.width else { return (anchor, frame) }
        // The anchor keeps its side of the screen, so it moves as little as possible.
        let anchorFirst = anchor.midX < screen.midX
        let start = min(max(anchorFirst ? anchor.minX : anchor.maxX - total, screen.minX), screen.maxX - total)
        let moved = CGRect(x: anchorFirst ? start : start + size.width + gap, y: anchor.minY,
                           width: anchor.width, height: anchor.height)
        let window = beside(moved, size: size, in: screen, gap: gap)
        return (moved, window)
    }
}
/// Opens on the rising edge of the trigger combination, never while it is held.
/// Without this the wheel would pop back up instantly after being dragged away,
/// because the modifier is usually still down at that moment — and suppressing
/// it instead would kill the trigger for the rest of the drag.
public struct TriggerLatch {
    public private(set) var isHeld = false
    public init() {}

    /// True exactly once per fresh press.
    @discardableResult
    public mutating func update(armed: Bool, satisfied: Bool) -> Bool {
        // Not armed yet: forget the keys, so becoming armed while they are
        // already held still counts as a fresh press. In Finder shift doubles
        // as the multi-select key and is often down before the drag starts.
        guard armed else { isHeld = false; return false }
        defer { isHeld = satisfied }
        return satisfied && !isHeld
    }
}

/// New pasteboard contents during a press arm the menu; stale contents never do.
public struct DragSessionTracker {
    public private(set) var isArmed = false
    private var wasDown = false
    private var generationChangedDuringPress = false
    private var lastCount: Int
    public init(pasteboardCount: Int) { lastCount = pasteboardCount }
    @discardableResult public mutating func update(buttonDown: Bool, pasteboardCount: Int, hasFiles: Bool) -> Bool {
        let changed = pasteboardCount != lastCount
        lastCount = pasteboardCount
        if !buttonDown { isArmed = false; generationChangedDuringPress = false }
        else {
            if !wasDown { isArmed = false; generationChangedDuringPress = false }
            if changed { generationChangedDuringPress = true }
            if generationChangedDuringPress && hasFiles { isArmed = true }
        }
        wasDown = buttonDown
        return isArmed
    }
}
