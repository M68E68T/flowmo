import AppKit
import SwiftUI
import FlowmoCore

final class RadialMenuView: NSView {
    var actions: [FileAction] = [] { didSet {
        guard actions != oldValue else { return }
        crossfade()
        selected = nil; glass.isHidden = actions.isEmpty
        painter.needsDisplay = true; centerLabel.needsDisplay = true
        refreshHighlight(); updateAccessibility()
    } }
    var urls: [URL] = [] { didSet { if urls != oldValue { centerLabel.needsDisplay = true } } }
    var onAction: ((FileAction, [URL]) -> Void)?
    var onExit: (() -> Void)?
    var onDragEntered: (([URL]) -> Void)?
    var selected: Int? { didSet { if oldValue != selected { centerLabel.needsDisplay = true; moveHighlight(from: oldValue) } } }
    let isInteractive: Bool
    var isFloating = true
    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    var radius: CGFloat { min(bounds.width, bounds.height) / 2 - 13 }
    private let glass = NSVisualEffectView()
    private let painter = RadialDrawingView()
    /// The hot sector is a mask turned around the centre instead of a repaint,
    /// so it glides from one action to the next and hovering never redraws the wheel.
    private let highlight = RadialHighlightView()
    private let centerLabel = RadialCenterView()
    private(set) var highlightAngle = 0.0
    /// Last pointer angle around the centre and which way it was last moving,
    /// so the highlight turns with the hand rather than the short way round.
    private var pointerAngle: Double?
    private var pointerClockwise: Bool?
    private var tracking: NSTrackingArea?
    override var acceptsFirstResponder: Bool { true }

    override convenience init(frame: NSRect) { self.init(frame: frame, interactive: true) }
    init(frame: NSRect, interactive: Bool) {
        isInteractive = interactive
        super.init(frame: frame)
        wantsLayer = true
        glass.isHidden = actions.isEmpty
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .aqua)
        glass.setAccessibilityElement(false)
        addSubview(glass)
        painter.owner = self
        painter.wantsLayer = true
        painter.setAccessibilityElement(false)
        addSubview(painter, positioned: .above, relativeTo: glass)
        highlight.setAccessibilityElement(false)
        addSubview(highlight, positioned: .above, relativeTo: painter)
        centerLabel.owner = self
        centerLabel.setAccessibilityElement(false)
        addSubview(centerLabel, positioned: .above, relativeTo: highlight)
        if interactive { registerForDraggedTypes([.fileURL]) }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("flowmo.radial-menu")
        setAccessibilityLabel(tr("menu.wheelLabel"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
    override func layout() {
        super.layout()
        let r = radius + 5
        let circle = CGRect(x: center.x-r,y: center.y-r,width:r*2,height:r*2)
        glass.frame=bounds;painter.frame=bounds;highlight.frame=bounds
        centerLabel.frame = CGRect(x: center.x - 44, y: center.y - 20, width: 88, height: 40)
        glass.maskImage = NSImage(size:bounds.size,flipped:false) { _ in
            NSColor.white.setFill(); NSBezierPath(ovalIn:circle).fill(); return true
        }
        refreshHighlight()
        updateAccessibility()
    }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); refreshHighlight() }
    /// Swapping the action set (tools key, new selection) cross-fades the
    /// whole wheel instead of snapping between two drawings.
    private func crossfade() {
        guard window != nil, let layer else { return }
        let fade = CATransition()
        fade.type = .fade
        fade.duration = Motion.reduced ? Motion.Duration.reduced : Motion.Duration.fade
        fade.timingFunction = Motion.easeInOut
        layer.add(fade, forKey: "actions")
    }
    private func refreshHighlight() {
        guard !actions.isEmpty, bounds.width > 0 else { return }
        let outer = radius, inner = outer * 0.385
        let step = 360 / Double(actions.count)
        let high = (90 + step / 2 - 1.0) * .pi / 180
        let path = roundedSector(outer: outer, inner: inner, high: high, low: high - (step - 2.0) * .pi / 180, corner: 12)
        let scale = window?.backingScaleFactor ?? 2
        highlight.update(path: path, labels: renderLabels(scale: scale), scale: scale)
    }
    private func moveHighlight(from old: Int?) {
        guard let selected, actions.indices.contains(selected) else { highlight.show(false); return }
        let target = old.map {
            RadialGeometry.rotation(to: selected, from: $0, count: actions.count,
                                    current: highlightAngle, clockwise: pointerClockwise)
        } ?? RadialGeometry.rotation(to: selected, count: actions.count, from: highlightAngle)
        // Entering from outside lands directly; only a move between sectors glides.
        highlight.turn(from: highlightAngle, to: target, animated: old != nil && window != nil && !Motion.reduced)
        highlightAngle = target
        highlight.show(true)
    }
    /// White copies of the labels, revealed only under the highlight mask, so
    /// the text colour changes exactly where the orange is at every frame.
    private func renderLabels(scale: CGFloat) -> CGImage? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * scale),
                                         pixelsHigh: Int(bounds.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawLabels(color: .white)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
    override func hitTest(_ point: NSPoint) -> NSView? { isInteractive && bounds.contains(convert(point,from:superview)) ? self : nil }
    private func updateAccessibility() {
        guard isInteractive else {
            setAccessibilityRole(.image)
            setAccessibilityLabel(tr("intro.wheelIllustration"))
            setAccessibilityChildren([])
            return
        }
        let elements: [NSAccessibilityElement] = actions.enumerated().map { index, action in
            let angle = (90 - Double(index) * 360 / Double(actions.count)) * .pi / 180
            let r = (radius + 60) / 2
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            let element = RadialActionElement()
            element.setAccessibilityRole(.button)
            element.setAccessibilityEnabled(true)
            element.setAccessibilityLabel(action.title)
            element.setAccessibilityParent(self)
            element.setAccessibilityFrameInParentSpace(CGRect(x: point.x-36, y: point.y-25, width:72,height:50))
            element.press = { [weak self] in guard let self else { return }; self.selected=index; self.onAction?(action,self.urls) }
            return element
        }
        setAccessibilityChildren(elements)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        guard isInteractive else { tracking = nil; return }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(tracking!)
    }
    func updateSelection(_ point: CGPoint) {
        let angle = RadialGeometry.angle(of: point, around: center)
        if let previous = pointerAngle {
            let delta = RadialGeometry.turn(from: previous, to: angle)
            if delta != 0 { pointerClockwise = delta > 0 }
        }
        pointerAngle = angle
        selected = RadialGeometry.index(point: point, center: center, inner: radius * 0.385, outer: radius, count: actions.count)
    }
    /// A pointer coming back in starts a fresh gesture.
    private func forgetPointer() { pointerAngle = nil; pointerClockwise = nil }
    override func mouseMoved(with event: NSEvent) { updateSelection(convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { forgetPointer(); selected = nil }
    override func mouseDown(with event: NSEvent) {
        guard isInteractive else { return }
        updateSelection(convert(event.locationInWindow, from: nil))
        if let selected { onAction?(actions[selected], urls) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onExit?() } else { super.keyDown(with: event) }
    }
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [])
            .filter { $0.isFileURL }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let incoming = Self.fileURLs(from: sender.draggingPasteboard)
        guard !incoming.isEmpty else { return [] }
        urls = incoming; onDragEntered?(incoming)
        updateSelection(convert(sender.draggingLocation, from: nil))
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateSelection(convert(sender.draggingLocation, from: nil))
        return selected == nil ? [] : .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { forgetPointer(); selected = nil; if isFloating { onExit?() } }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        updateSelection(convert(sender.draggingLocation, from: nil)); return selected != nil
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        updateSelection(convert(sender.draggingLocation, from: nil))
        guard let selected, actions.indices.contains(selected) else { return false }
        let incoming = Self.fileURLs(from: sender.draggingPasteboard)
        guard !incoming.isEmpty else { return false }
        let action = actions[selected]
        onAction?(action, incoming)
        return true
    }
    override func draggingEnded(_ sender: NSDraggingInfo) { if isFloating { onExit?() } }

    func drawWheel(_ dirtyRect: NSRect) {
        guard !actions.isEmpty else { return }
        let outer = radius, inner = outer * 0.385
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 8; shadow.shadowOffset = NSSize(width: 0, height: -2); shadow.set()
        let disc = NSBezierPath(ovalIn: CGRect(x: center.x - outer - 6, y: center.y - outer - 6, width: (outer + 6) * 2, height: (outer + 6) * 2))
        NSColor(calibratedRed: 0.88, green: 0.71, blue: 0.49, alpha: 0.18).setFill(); disc.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.55).setStroke(); disc.lineWidth = 0.8; disc.stroke()
        let step = 360 / Double(actions.count)
        for index in actions.indices {
            let high = (90 - Double(index) * step + step / 2 - 1.0) * .pi / 180
            let low = high - (step - 2.0) * .pi / 180
            let path = roundedSector(outer: outer, inner: inner, high: high, low: low, corner: 12)
            let top = NSColor(calibratedWhite: 1, alpha: 0.57)
            let bottom = NSColor(calibratedRed: 1, green: 0.86, blue: 0.78, alpha: 0.50)
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState(); context.addPath(path); context.clip()
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor,bottom.cgColor] as CFArray, locations: [0,1])!
                context.drawLinearGradient(gradient,start:CGPoint(x:0,y:bounds.maxY),end:CGPoint(x:0,y:0),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
                context.restoreGState()
                context.addPath(path); context.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor); context.setLineWidth(0.6); context.strokePath()
            }
        }
        drawLabels(color: .black)
        let r = inner - 6
        let middle = NSBezierPath(ovalIn: CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2))
        NSColor(calibratedRed: 1,green:0.53,blue:0.20,alpha:0.17).setFill(); middle.fill()
        NSColor.white.withAlphaComponent(0.5).setStroke(); middle.lineWidth = 0.7; middle.stroke()
        let pill = NSBezierPath(roundedRect: CGRect(x: center.x - 44, y: center.y - 20, width: 88, height: 40), xRadius: 20, yRadius: 20)
        NSColor(calibratedRed: 1, green: 0.86, blue: 0.61, alpha: 0.73).setFill(); pill.fill()
        NSColor.white.withAlphaComponent(0.35).setStroke();pill.lineWidth=0.6;pill.stroke()
    }
    func drawLabels(color: NSColor) {
        guard !actions.isEmpty else { return }
        let outer = radius, inner = outer * 0.385
        let step = 360 / Double(actions.count)
        for (index, action) in actions.enumerated() {
            let angle = (90 - Double(index) * step) * .pi / 180
            let r = (outer + inner) / 2
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            // Wide sectors (up to four) fit full-size words; the steps are for six.
            let fontSize: CGFloat = actions.count <= 4 && action.title.count <= 12 ? 14
                : (action.title.count > 9 ? 10 : (action.title.count > 6 ? 11 : 14))
            drawText(action.title, at: point, font: .systemFont(ofSize: fontSize, weight: .semibold), color: color)
        }
    }
    /// Drawn in the centre view's own coordinates; repainted alone on hover.
    func drawCenterLabel(in rect: CGRect) {
        guard !actions.isEmpty else { return }
        let label = selected.flatMap { actions.indices.contains($0) ? actions[$0].title : nil } ?? (urls.first?.pathExtension.uppercased() ?? "")
        drawText(label, at: CGPoint(x: rect.midX, y: rect.midY), font: .systemFont(ofSize: label.count > 8 ? 9 : 13, weight: .semibold), color: .black)
    }
    private func roundedSector(outer: CGFloat, inner: CGFloat, high: Double, low: Double, corner: CGFloat) -> CGPath {
        func p(_ r: CGFloat,_ a: Double) -> CGPoint { CGPoint(x:center.x+r*cos(a),y:center.y+r*sin(a)) }
        let oa = corner / outer, ia = corner / inner
        let path = CGMutablePath()
        path.move(to:p(outer,high-oa))
        path.addArc(center:center,radius:outer,startAngle:high-oa,endAngle:low+oa,clockwise:true)
        path.addQuadCurve(to:p(outer-corner,low),control:p(outer,low))
        path.addLine(to:p(inner+corner,low))
        path.addQuadCurve(to:p(inner,low+ia),control:p(inner,low))
        path.addArc(center:center,radius:inner,startAngle:low+ia,endAngle:high-ia,clockwise:false)
        path.addQuadCurve(to:p(inner+corner,high),control:p(inner,high))
        path.addLine(to:p(outer-corner,high))
        path.addQuadCurve(to:p(outer,high-oa),control:p(outer,high));path.closeSubpath()
        return path
    }
    private func drawText(_ string: String, at point: CGPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), withAttributes: attrs)
    }
}

private final class RadialDrawingView: NSView {
    weak var owner: RadialMenuView?
    override var isOpaque: Bool { false }
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect:NSRect) { owner?.drawWheel(dirtyRect) }
}

private final class RadialCenterView: NSView {
    weak var owner: RadialMenuView?
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { owner?.drawCenterLabel(in: bounds) }
}

/// Orange fill plus white labels, both cut out by the same sector mask.
/// Plain sublayers, not view backing layers, so AppKit never resets the
/// opacity or transforms the animations work on.
private final class RadialHighlightView: NSView {
    private let group = CALayer()
    private let fill = CAGradientLayer()
    private let ink = CALayer()
    private let masks = [CAShapeLayer(), CAShapeLayer()]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        fill.colors = [NSColor(calibratedRed: 0.90, green: 0.24, blue: 0.015, alpha: 0.95).cgColor,
                       NSColor(calibratedRed: 1, green: 0.34, blue: 0.08, alpha: 0.96).cgColor]
        fill.startPoint = CGPoint(x: 0.5, y: 1); fill.endPoint = CGPoint(x: 0.5, y: 0)
        fill.mask = masks[0]; ink.mask = masks[1]
        group.addSublayer(fill); group.addSublayer(ink)
        group.opacity = 0
        layer?.addSublayer(group)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(path: CGPath, labels: CGImage?, scale: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for sublayer in [group, fill, ink] { sublayer.frame = bounds }
        for mask in masks {
            mask.bounds = bounds
            mask.position = CGPoint(x: bounds.midX, y: bounds.midY)
            mask.path = path
        }
        ink.contents = labels; ink.contentsScale = scale
        CATransaction.commit()
    }
    func show(_ visible: Bool) {
        let target: Float = visible ? 1 : 0
        guard group.opacity != target else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = group.presentation()?.opacity ?? group.opacity
        fade.toValue = target
        fade.duration = Motion.Duration.short
        fade.timingFunction = visible ? Motion.easeOut : Motion.easeIn
        CATransaction.begin(); CATransaction.setDisableActions(true)
        group.opacity = target
        CATransaction.commit()
        group.add(fade, forKey: "fade")
    }
    /// Additive, so a new target picked mid-glide continues from wherever the
    /// highlight currently is instead of jumping back first.
    func turn(from: Double, to: Double, animated: Bool) {
        for mask in masks {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            mask.setValue(to, forKeyPath: "transform.rotation.z")
            CATransaction.commit()
            guard animated, from != to else { continue }
            let glide = Motion.spring("transform.rotation.z")
            glide.isAdditive = true
            glide.fromValue = from - to
            glide.toValue = 0.0
            mask.add(glide, forKey: nil)
        }
    }
}

private final class RadialActionElement: NSAccessibilityElement {
    var press: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { guard let press else { return false }; press(); return true }
}

struct EmbeddedWheel: NSViewRepresentable {
    let urls: [URL]
    let tools: Bool
    let action: (FileAction, [URL]) -> Void
    let receive: ([URL]) -> Void
    func makeNSView(context: Context) -> RadialMenuView {
        let view = RadialMenuView(frame: .zero); view.isFloating = false; return view
    }
    func updateNSView(_ view: RadialMenuView, context: Context) {
        let options = ActionCatalog.actions(for: urls, tools: tools)
        if view.actions != options { view.actions = options }
        view.urls = urls; view.onAction = action; view.onDragEntered = receive
    }
}

/// Shares the wheel painter, but installs no tracking, drop types or actions.
struct WheelIllustration: NSViewRepresentable {
    let tools: Bool
    func makeNSView(context: Context) -> RadialMenuView { RadialMenuView(frame: .zero, interactive: false) }
    func updateNSView(_ view: RadialMenuView, context: Context) {
        let sample = URL(fileURLWithPath: "/example.png")
        view.actions = ActionCatalog.actions(for: [sample], tools: tools)
        view.urls = [sample]
    }
}
