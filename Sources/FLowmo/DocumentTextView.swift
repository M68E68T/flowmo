import AppKit
import SwiftUI
import FLowmoCore

final class DocumentTextView: NSTextView {
    weak var model: DocumentEditorModel?
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        model?.flushTyping()
        super.mouseDown(with: event)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode >= 123 && event.keyCode <= 126 { model?.flushTyping() }
        super.keyDown(with: event)
    }
    @objc func undo(_ sender: Any?) { model?.undo() }
    @objc func redo(_ sender: Any?) { model?.redo() }
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return model?.canUndo ?? false }
        if item.action == #selector(redo(_:)) { return model?.canRedo ?? false }
        return super.validateUserInterfaceItem(item)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if performEditorCommand(with: event) { return true }
        return super.performKeyEquivalent(with: event)
    }
    func performEditorCommand(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command), let model, !model.saving else { return false }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z": event.modifierFlags.contains(.shift) ? model.redo() : model.undo()
        case "b": model.toggleBold()
        case "i": model.toggleItalic()
        case "u": model.toggleUnderline()
        case "0": model.zoom = nil
        case "+", "=": model.stepZoom(1)
        case "-": model.stepZoom(-1)
        default: return false
        }
        return true
    }
    override func insertNewline(_ sender: Any?) {
        guard let storage = textStorage else { super.insertNewline(sender); return }
        let range = (storage.string as NSString).paragraphRange(for: selectedRange())
        let paragraph = (storage.string as NSString).substring(with: range)
        let style = range.location < storage.length ? storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle : nil
        guard !(style?.textLists.isEmpty ?? true), let prefix = DocumentLists.prefix(in: paragraph) else {
            model?.flushTyping(); super.insertNewline(sender); return
        }
        if paragraph.trimmingCharacters(in: .whitespacesAndNewlines) == prefix.trimmingCharacters(in: .whitespacesAndNewlines) {
            model?.setList(.none); return
        }
        model?.flushTyping()
        super.insertNewline(sender)
        let next = (string as NSString).paragraphRange(for: selectedRange())
        // Some macOS releases continue a native list themselves.
        guard DocumentLists.prefix(in: (string as NSString).substring(with: next)) == nil else { return }
        let number = Int(prefix.filter(\.isNumber))
        insertText(number.map { "\($0 + 1).\t" } ?? "•\t", replacementRange: selectedRange())
    }
}

private final class DocumentPaperView: NSView {
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}

private final class DocumentPageSurface: NSView {
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

final class DocumentPagesScrollView: NSScrollView {
    weak var model: DocumentEditorModel?
    var editorActive = true
    private let surface = DocumentPageSurface()
    private var papers: [DocumentPaperView] = []
    private(set) var textViews: [DocumentTextView] = []
    private weak var installedLayout: DocumentLayout?
    private var fit: CGFloat = 1
    private var synchronizing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = true; backgroundColor = .black.withAlphaComponent(0.045)
        hasVerticalScroller = true; hasHorizontalScroller = true
        autohidesScrollers = true
        allowsMagnification = true; minMagnification = 0.1; maxMagnification = 6
        documentView = surface
    }
    required init?(coder: NSCoder) { fatalError() }
    override var mouseDownCanMoveWindow: Bool { false }
    override func layout() { super.layout(); synchronize() }
    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        if !synchronizing { model?.zoom = Double(magnification) }
    }

    func synchronize() {
        guard !synchronizing, let model, let layout = model.layout else { return }
        synchronizing = true
        defer { synchronizing = false }
        if installedLayout !== layout {
            textViews.removeAll(); papers.forEach { $0.removeFromSuperview() }; papers.removeAll()
            installedLayout = layout
        }
        while textViews.count > layout.containers.count {
            if let view = textViews.last, window?.firstResponder === view {
                window?.makeFirstResponder(textViews.first)
            }
            textViews.removeLast(); papers.removeLast().removeFromSuperview()
        }
        while textViews.count < layout.containers.count {
            let paper = DocumentPaperView(frame: CGRect(origin: .zero, size: DocumentLayout.paper))
            let container = layout.containers[textViews.count]
            let view = DocumentTextView(frame: CGRect(origin: CGPoint(x: 48, y: 48), size: DocumentLayout.textSize), textContainer: container)
            container.widthTracksTextView = false; container.heightTracksTextView = false
            view.model = model; view.delegate = model
            view.isRichText = true; view.importsGraphics = false; view.allowsUndo = false
            view.drawsBackground = false; view.textContainerInset = .zero
            view.isHorizontallyResizable = false; view.isVerticallyResizable = false
            view.usesAdaptiveColorMappingForDarkAppearance = false
            view.insertionPointColor = .black; view.textColor = .black
            view.typingAttributes = model.activeTextView?.typingAttributes
                ?? (layout.storage.length > 0 ? layout.storage.attributes(at: 0, effectiveRange: nil) : DocumentImporter.defaultAttributes)
            view.setAccessibilityLabel(tr("document.textPage", textViews.count + 1))
            paper.addSubview(view); surface.addSubview(paper)
            papers.append(paper); textViews.append(view)
        }
        for view in textViews { view.isEditable = editorActive && !model.saving }
        let available = contentView.bounds.size
        guard available.width > 0, available.height > 0 else { return }
        // Scroll-view magnification changes its clip bounds. Use the unscaled
        // viewport so repeated SwiftUI updates never progressively zoom out.
        let viewport = contentSize
        fit = max(0.1, min(1, min((viewport.width - 32) / DocumentLayout.paper.width,
                                (viewport.height - 24) / DocumentLayout.paper.height)))
        let scale = min(maxMagnification, max(minMagnification, model.zoom ?? Double(fit)))
        model.viewScale = Double(scale)
        let width = max(DocumentLayout.paper.width + 32, viewport.width / scale)
        surface.setFrameSize(CGSize(width: width, height: CGFloat(papers.count) * (DocumentLayout.paper.height + 20) + 20))
        for (index, paper) in papers.enumerated() {
            paper.setFrameOrigin(CGPoint(x: (width - DocumentLayout.paper.width) / 2,
                                         y: 20 + CGFloat(index) * (DocumentLayout.paper.height + 20)))
        }
        if abs(magnification - scale) > 0.001 { magnification = scale }
        if model.activeTextView == nil, let first = textViews.first {
            model.activeTextView = first
            first.setSelectedRange(model.selection)
            DispatchQueue.main.async { [weak self, weak first] in
                guard self?.editorActive == true, let first, !first.isHiddenOrHasHiddenAncestor else { return }
                first.window?.makeFirstResponder(first)
            }
        }
    }
}

struct DocumentPages: NSViewRepresentable {
    @ObservedObject var model: DocumentEditorModel
    var active = true
    func makeNSView(context: Context) -> DocumentPagesScrollView {
        let view = DocumentPagesScrollView(frame: .zero); view.model = model; view.editorActive = active
        return view
    }
    func updateNSView(_ view: DocumentPagesScrollView, context: Context) { view.editorActive = active; view.synchronize() }
}
