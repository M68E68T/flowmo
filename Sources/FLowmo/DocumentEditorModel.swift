import AppKit
import SwiftUI
import FLowmoCore

@MainActor final class DocumentEditorModel: NSObject, ObservableObject, NSTextViewDelegate {
    @Published private(set) var layout: DocumentLayout?
    @Published private(set) var revision = 0
    @Published private(set) var loading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var usedOCR = false
    @Published private(set) var dirty = false
    @Published private(set) var saving = false
    @Published var message: String?
    @Published var zoom: Double? = 1
    var viewScale: Double = 1
    @Published var outputFormat: OutputFormat = .pdf
    @Published private(set) var lastOutput: URL?
    private(set) var selection = NSRange(location: 0, length: 0)
    weak var activeTextView: DocumentTextView?
    private var history = UndoStack(DocumentSnapshot(NSAttributedString(string: "")))
    private var saved = DocumentSnapshot(NSAttributedString(string: ""))
    private var typingCommit: Task<Void, Never>?
    private var worker: Task<DocumentImportResult, Error>?
    private var generation = UUID()
    private var restoring = false
    var completed: ((URL) -> Void)?

    var attributes: [NSAttributedString.Key: Any] {
        guard let storage = layout?.storage else { return DocumentImporter.defaultAttributes }
        if selection.length == 0, let view = activeTextView { return view.typingAttributes }
        guard storage.length > 0 else { return DocumentImporter.defaultAttributes }
        return storage.attributes(at: min(selection.location, storage.length - 1), effectiveRange: nil)
    }
    var font: NSFont { attributes[.font] as? NSFont ?? NSFont(name: "Helvetica", size: 12)! }
    var color: NSColor { attributes[.foregroundColor] as? NSColor ?? .black }
    var alignment: NSTextAlignment { (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .left }
    var bold: Bool { NSFontManager.shared.traits(of: font).contains(.boldFontMask) }
    var italic: Bool { NSFontManager.shared.traits(of: font).contains(.italicFontMask) }
    var underlined: Bool { (attributes[.underlineStyle] as? Int ?? 0) != 0 }
    var canUndo: Bool { history.canUndo || snapshot != history.current }
    var canRedo: Bool { history.canRedo }
    var canSave: Bool { layout != nil && !snapshot.isEmpty && !loading && !saving }
    var snapshot: DocumentSnapshot { DocumentSnapshot(layout?.storage ?? NSAttributedString(string: ""), selection: selection) }

    func load(_ url: URL) async {
        guard layout == nil, !loading else { return }
        let token = UUID(); generation = token
        loading = true; progress = 0; message = nil
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            try DocumentImporter.read(url, progress: { current, total in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.progress = Double(current) / Double(max(1, total))
                }
            }, isCancelled: { Task<Never, Never>.isCancelled })
        }
        worker = task
        do {
            let result = try await task.value
            guard generation == token else { return }
            try install(result.document)
            usedOCR = result.usedOCR
        } catch {
            guard generation == token else { return }
            message = error is CancellationError ? tr("document.importCancelled") : error.localizedDescription
        }
        if generation == token { loading = false; worker = nil }
    }

    func cancelImport() {
        generation = UUID(); worker?.cancel(); worker = nil
        if loading { loading = false; message = tr("document.importCancelled") }
    }

    func install(_ document: DocumentSnapshot) throws {
        layout = try DocumentLayout(document)
        saved = document; history = UndoStack(document)
        selection = document.selection; dirty = false; revision += 1
    }

    func textDidChange(_ notification: Notification) {
        guard !restoring else { return }
        if let view = notification.object as? DocumentTextView { activeTextView = view; selection = view.selectedRange() }
        refreshLayout()
        typingCommit?.cancel()
        guard activeTextView?.hasMarkedText() != true else { return }
        typingCommit = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.flushTyping()
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !restoring, let view = notification.object as? DocumentTextView else { return }
        activeTextView = view; selection = view.selectedRange()
        objectWillChange.send()
    }

    func flushTyping() {
        typingCommit?.cancel()
        guard layout != nil, activeTextView?.hasMarkedText() != true else { return }
        history.commitIfChanged(snapshot)
        objectWillChange.send()
    }

    func undo() { guard !saving else { return }; flushTyping(); if let value = history.undo() { restore(value) } }
    func redo() { guard !saving else { return }; flushTyping(); if let value = history.redo() { restore(value) } }
    private func restore(_ value: DocumentSnapshot) {
        guard let storage = layout?.storage else { return }
        restoring = true
        storage.setAttributedString(value.text)
        selection = value.selection
        refreshLayout()
        activeTextView?.setSelectedRange(clamped(selection))
        restoring = false
    }

    private func clamped(_ range: NSRange) -> NSRange {
        let count = layout?.storage.length ?? 0
        let start = min(range.location, count)
        return NSRange(location: start, length: min(range.length, count - start))
    }
    private func refreshLayout() {
        dirty = snapshot != saved
        do { try layout?.paginate() }
        catch { message = error.localizedDescription }
        revision += 1
    }
    private func format(_ edit: (NSMutableAttributedString, NSRange) -> Void) {
        guard !saving, let storage = layout?.storage else { return }
        if let view = activeTextView { selection = view.selectedRange() }
        flushTyping()
        let range = clamped(selection)
        storage.beginEditing(); edit(storage, range); storage.endEditing()
        refreshLayout(); history.commitIfChanged(snapshot)
        activeTextView?.setSelectedRange(clamped(selection))
    }

    private func characterAttribute(_ key: NSAttributedString.Key, value: Any) {
        guard !saving else { return }
        if selection.length == 0, let view = activeTextView {
            flushTyping()
            var attributes = view.typingAttributes; attributes[key] = value
            view.typingAttributes = attributes; objectWillChange.send()
        } else { format { $0.addAttribute(key, value: value, range: $1) } }
    }

    func setFontFamily(_ family: String) {
        changeFonts { NSFontManager.shared.convert($0, toFamily: family) }
    }
    func setFontSize(_ size: Double) {
        guard size.isFinite else { return }
        changeFonts { NSFontManager.shared.convert($0, toSize: min(144, max(6, size))) }
    }
    func toggleBold() { toggleTrait(.boldFontMask, enabled: bold) }
    func toggleItalic() { toggleTrait(.italicFontMask, enabled: italic) }
    private func toggleTrait(_ trait: NSFontTraitMask, enabled: Bool) {
        changeFonts { enabled ? NSFontManager.shared.convert($0, toNotHaveTrait: trait) : NSFontManager.shared.convert($0, toHaveTrait: trait) }
    }
    private func changeFonts(_ change: (NSFont) -> NSFont) {
        if selection.length == 0 { characterAttribute(.font, value: change(font)); return }
        format { storage, range in
            storage.enumerateAttribute(.font, in: range) { value, run, _ in
                storage.addAttribute(.font, value: change(value as? NSFont ?? NSFont(name: "Helvetica", size: 12)!), range: run)
            }
        }
    }
    func toggleUnderline() { characterAttribute(.underlineStyle, value: underlined ? 0 : NSUnderlineStyle.single.rawValue) }
    func setColor(_ color: NSColor) { characterAttribute(.foregroundColor, value: color) }
    func setAlignment(_ alignment: NSTextAlignment) {
        format { storage, range in
            let paragraphs = (storage.string as NSString).paragraphRange(for: range)
            if paragraphs.length == 0 {
                let style = NSMutableParagraphStyle(); style.alignment = alignment
                self.activeTextView?.typingAttributes[.paragraphStyle] = style.copy() as! NSParagraphStyle
            } else {
                storage.enumerateAttribute(.paragraphStyle, in: paragraphs) { value, run, _ in
                    let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    style.alignment = alignment
                    storage.addAttribute(.paragraphStyle, value: style.copy() as! NSParagraphStyle, range: run)
                }
            }
        }
    }
    func setList(_ style: DocumentListStyle) {
        format { storage, range in self.selection = DocumentLists.apply(style, to: storage, selection: range) }
        if style == .none, selection.length == 0, let view = activeTextView {
            let paragraph = (view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            paragraph.textLists = []; paragraph.headIndent = 0; paragraph.firstLineHeadIndent = 0
            view.typingAttributes[.paragraphStyle] = paragraph.copy() as! NSParagraphStyle
        }
    }

    func save(beside input: URL) {
        guard canSave else { return }
        activeTextView?.unmarkText(); flushTyping()
        let document = snapshot, format = outputFormat
        saving = true; message = nil
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) {
                    try DocumentExporter.write(document, as: format, beside: input)
                }.value
                saved = document; dirty = snapshot != saved; lastOutput = output
                completed?(output)
            } catch { message = error.localizedDescription }
            saving = false
        }
    }

    func stepZoom(_ direction: Int) {
        let steps = AnnotationLayout.zoomSteps, current = zoom ?? viewScale
        zoom = direction > 0 ? (steps.first { $0 > current + 0.001 } ?? steps.last)
            : (steps.last { $0 < current - 0.001 } ?? steps.first)
    }
}
