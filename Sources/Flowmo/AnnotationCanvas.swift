import AppKit
import SwiftUI
import FlowmoCore

/// Which tool the next drag creates.
enum AnnotationTool: String, CaseIterable, Identifiable {
    case select, text, signature, arrow, rectangle, highlight, redaction
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .text: return "textformat"
        case .signature: return "signature"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .highlight: return "highlighter"
        case .redaction: return "eye.slash"
        }
    }
    var helpKey: String { "help.tool." + rawValue }
    var titleKey: String { "tool." + rawValue }
    /// Single letters, no modifier: the canvas has no text field to steal them.
    var shortcut: KeyEquivalent {
        switch self {
        case .select: return "v"
        case .text: return "t"
        case .signature: return "u"
        case .arrow: return "p"
        case .rectangle: return "r"
        case .highlight: return "m"
        case .redaction: return "s"
        }
    }
    var shortcutLabel: String { String(shortcut.character).uppercased() }
}

/// Places and moves annotations on top of a rendered page or image. Modelled on
/// CropSelectionView: plain AppKit drawing, mouse handling, normalized output.
final class AnnotationCanvasView: NSView {
    var backdrop: CGImage? { didSet { needsDisplay = true } }
    var annotations: [Annotation] = [] { didSet { needsDisplay = true } }
    var signatures: [String: CGImage] = [:] { didSet { needsDisplay = true } }
    var logicalSize: CGSize = .zero
    var selectionChanged: ((UUID?) -> Void)?
    var tool: AnnotationTool = .select
    var style = AnnotationStyle()
    var page = 0
    var began: (() -> Void)?
    var changed: (([Annotation]) -> Void)?
    /// Only fired once a gesture is finished. `changed` runs on every mouse
    /// move, which would otherwise fill the undo stack with hundreds of steps.
    var committed: (([Annotation]) -> Void)?
    var requestsText: ((UUID) -> Void)?
    var requestsSignature: ((UUID) -> Void)?
    var selected: UUID? { didSet { needsDisplay = true; if oldValue != selected { selectionChanged?(selected) } } }

    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var movingID: UUID?
    private var moveOffset = CGSize.zero
    private var resizing: (annotation: Annotation, handle: ResizeHandle)?
    private let handle: CGFloat = 9

    override var acceptsFirstResponder: Bool { true }
    // The window moves by its background, and a transparent view counts as
    // background: every stroke would also drag the window along.
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: tool == .select ? .arrow : .crosshair)
    }

    /// The area the backdrop actually covers, preserving its aspect ratio.
    var contentRect: CGRect {
        guard let backdrop, backdrop.width > 0, backdrop.height > 0 else { return bounds }
        let factor = min(bounds.width / Double(backdrop.width), bounds.height / Double(backdrop.height))
        let size = CGSize(width: Double(backdrop.width) * factor, height: Double(backdrop.height) * factor)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
    private func handles(for annotation: Annotation) -> [ResizeHandle] {
        annotation.kind == .arrow ? AnnotationGeometry.arrowHandles(flipped: annotation.arrowFlipped, reversed: annotation.arrowReversed) : ResizeHandle.allCases
    }
    private func normalized(_ rect: CGRect) -> CGRect {
        let area = contentRect
        guard area.width > 0, area.height > 0 else { return .zero }
        return CGRect(x: (rect.minX - area.minX) / area.width, y: (rect.minY - area.minY) / area.height,
                      width: rect.width / area.width, height: rect.height / area.height)
    }

    override func mouseDown(with event: NSEvent) {
        began?()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        // Handles first: an element covers its own corners, so testing the
        // body before them would make edge handles unreachable.
        if let current = selected, let annotation = annotations.first(where: { $0.id == current }),
           annotation.page == page,
           let grabbed = AnnotationGeometry.handle(at: point, of: annotation.rect(in: contentRect),
                                                   candidates: handles(for: annotation),
                                                   tolerance: handle) {
            resizing = (annotation, grabbed)
            return
        }
        let hit = annotations.on(page: page).reversed()
            .first { $0.rect(in: contentRect).insetBy(dx: -4, dy: -4).contains(point) }
        // Double-click reopens the text, which is otherwise final once set.
        if event.clickCount == 2, let hit, case .text = hit.kind {
            selected = hit.id
            requestsText?(hit.id)
            return
        }
        if tool == .select {
            // Topmost first, so stacked annotations pick the visible one.
            if let hit {
                selected = hit.id
                movingID = hit.id
                let rect = hit.rect(in: contentRect)
                moveOffset = CGSize(width: point.x - rect.minX, height: point.y - rect.minY)
            } else { selected = nil }
            return
        }
        // Otherwise a set signature could never be exchanged again.
        if tool == .signature, let hit, case .signature = hit.kind {
            selected = hit.id
            requestsSignature?(hit.id)
            return
        }
        guard contentRect.contains(point) else { return }
        dragStart = point; dragCurrent = point
    }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let resizing, let index = annotations.firstIndex(where: { $0.id == resizing.annotation.id }) {
            let rect = resizing.annotation.rect(in: contentRect)
            if resizing.annotation.kind == .arrow {
                // The dragged end follows the pointer, the other stays put.
                let annotation = resizing.annotation
                let fixed = AnnotationGeometry.arrowPoints(in: rect, flipped: annotation.arrowFlipped,
                                                           reversed: annotation.arrowReversed)
                let movingStart = resizing.handle == handles(for: annotation)[0]
                let result = movingStart ? AnnotationGeometry.arrow(from: point, to: fixed.end)
                    : AnnotationGeometry.arrow(from: fixed.start, to: point)
                annotations[index].frame = normalized(result.rect)
                annotations[index].arrowFlipped = result.flipped
                annotations[index].arrowReversed = result.reversed
            } else {
                annotations[index].frame = normalized(AnnotationGeometry.resize(rect, handle: resizing.handle, to: point))
            }
            changed?(annotations)
            return
        }
        if let movingID, let index = annotations.firstIndex(where: { $0.id == movingID }) {
            let rect = annotations[index].rect(in: contentRect)
            let moved = CGRect(x: point.x - moveOffset.width, y: point.y - moveOffset.height,
                               width: rect.width, height: rect.height)
            annotations[index].frame = normalized(moved)
            changed?(annotations)
            return
        }
        guard dragStart != nil else { return }
        dragCurrent = point; needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        let wasEditing = movingID != nil || resizing != nil
        defer { dragStart = nil; dragCurrent = nil; movingID = nil; resizing = nil }
        if wasEditing { committed?(annotations); return }
        guard let start = dragStart, let end = dragCurrent else { return }
        var rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        // A plain click gets a usable default box instead of nothing.
        if tool == .arrow ? hypot(end.x - start.x, end.y - start.y) < 6 : (rect.width < 6 || rect.height < 6) {
            let fallback = tool == .signature ? CGSize(width: 190, height: 70) : CGSize(width: 170, height: 34)
            rect = CGRect(origin: start, size: fallback)
        }
        rect = rect.intersection(contentRect)
        guard tool == .arrow ? (rect.width > 2 || rect.height > 2) : (rect.width > 2 && rect.height > 2) else { return }
        let kind: AnnotationKind
        switch tool {
        case .select: return
        case .text: kind = .text("")
        case .signature: kind = .signature(id: "")
        case .arrow: kind = .arrow
        case .rectangle: kind = .rectangle
        case .highlight: kind = .highlight
        case .redaction: kind = .redaction
        }
        var annotation = Annotation(kind: kind, frame: normalized(rect), style: style, page: page)
        if tool == .arrow {
            let clicked = hypot(end.x - start.x, end.y - start.y) < 6
            let area = contentRect
            let tip = clicked ? CGPoint(x: rect.maxX, y: rect.maxY)
                : CGPoint(x: min(area.maxX, max(area.minX, end.x)), y: min(area.maxY, max(area.minY, end.y)))
            let arrow = AnnotationGeometry.arrow(from: start, to: tip)
            annotation.frame = normalized(arrow.rect)
            annotation.arrowFlipped = arrow.flipped
            annotation.arrowReversed = arrow.reversed
        }
        annotations.append(annotation)
        selected = annotation.id
        changed?(annotations)
        // Content is a draft until the dialog succeeds. Never put a blank
        // text/signature frame into undo history.
        if tool != .text && tool != .signature { committed?(annotations) }
        // Ask only once the frame exists — otherwise there is nothing to
        // assign the result to and the choice would be dropped.
        if case .text = kind { requestsText?(annotation.id) }
        if case .signature = kind { requestsSignature?(annotation.id) }
    }
    override func keyDown(with event: NSEvent) {
        // 51 = Backspace, 117 = Forward delete.
        guard event.keyCode == 51 || event.keyCode == 117, let selected else { super.keyDown(with: event); return }
        annotations.removeAll { $0.id == selected }
        self.selected = nil
        changed?(annotations)
        committed?(annotations)
    }

    /// Blends the next drawing over the current one. Drawing itself stays
    /// immediate, so strokes and handles never trail the pointer.
    func crossfade() {
        guard window != nil else { return }
        wantsLayer = true
        let fade = CATransition()
        fade.type = .fade
        fade.duration = Motion.reduced ? Motion.Duration.reduced : Motion.Duration.fade
        fade.timingFunction = Motion.easeInOut
        layer?.add(fade, forKey: "page")
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let area = contentRect
        if let backdrop {
            context.interpolationQuality = .high
            context.draw(backdrop, in: area)
        }
        AnnotationRenderer.draw(annotations.on(page: page), in: context, bounds: area, signatures: signatures, logicalSize: logicalSize)
        // Empty text and unassigned signatures would be invisible otherwise.
        for annotation in annotations.on(page: page) {
            let rect = annotation.rect(in: area)
            var placeholder = false
            if case .text(let value) = annotation.kind, value.isEmpty { placeholder = true }
            if case .signature(let id) = annotation.kind, signatures[id] == nil { placeholder = true }
            if placeholder {
                context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
                context.setLineDash(phase: 0, lengths: [4, 3])
                context.stroke(rect); context.setLineDash(phase: 0, lengths: [])
            }
            guard annotation.id == selected else { continue }
            context.setStrokeColor(ReferenceStyle.accentCG)
            context.setLineWidth(1.5)
            context.stroke(rect.insetBy(dx: -2, dy: -2))
            for grip in handles(for: annotation) {
                let corner = grip.point(in: rect)
                context.setFillColor(ReferenceStyle.accentCG)
                context.fillEllipse(in: CGRect(x: corner.x - handle / 2, y: corner.y - handle / 2, width: handle, height: handle))
            }
        }
        if let start = dragStart, let end = dragCurrent, tool != .select {
            context.setStrokeColor(ReferenceStyle.accentCG)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [5, 3])
            context.stroke(CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                  width: abs(end.x - start.x), height: abs(end.y - start.y)))
        }
    }
}

struct AnnotationCanvas: NSViewRepresentable {
    let backdrop: CGImage?
    @Binding var annotations: [Annotation]
    @Binding var selected: UUID?
    let signatures: [String: CGImage]
    let logicalSize: CGSize
    let tool: AnnotationTool
    let style: AnnotationStyle
    let page: Int
    let requestsText: (UUID) -> Void
    let requestsSignature: (UUID) -> Void
    let began: () -> Void
    let committed: ([Annotation]) -> Void

    func makeNSView(context: Context) -> AnnotationCanvasView { AnnotationCanvasView(frame: .zero) }
    func updateNSView(_ view: AnnotationCanvasView, context: Context) {
        // A new page or its freshly rendered backdrop cross-fades in place.
        if view.page != page || (view.backdrop != nil && view.backdrop !== backdrop) { view.crossfade() }
        view.backdrop = backdrop
        if view.annotations != annotations { view.annotations = annotations }
        view.signatures = signatures
        view.logicalSize = logicalSize
        view.tool = tool
        view.style = style
        view.page = page
        if view.selected != selected { view.selected = selected }
        view.selectionChanged = { next in if selected != next { selected = next } }
        view.changed = { annotations = $0 }
        view.requestsText = requestsText
        view.requestsSignature = requestsSignature
        view.began = began
        view.committed = committed
        view.window?.invalidateCursorRects(for: view)
    }
}
