import AppKit
import SwiftUI
import PDFKit
import FlowmoCore

/// One editor serves both file types; only the page strip differs.
enum AnnotationSource {
    case image(CGImage)
    case pdf(PDFDocument)
    var pageCount: Int { if case .pdf(let doc) = self { return doc.pageCount }; return 1 }
}

enum AnnotationLayout {
    static let size = CGSize(width: 1000, height: 780)
    static let minimum = CGSize(width: 720, height: 560)
    static let zoomSteps: [Double] = [0.5, 0.75, 1, 1.5, 2, 3, 4]
}

/// sheet(item:) needs an Identifiable, and a bare UUID is not one.
private struct SignatureRequest: Identifiable { let id: UUID }
private struct TextRequest: Identifiable { let id: UUID; let value: String }

struct AnnotationEditor: View {
    let file: URL
    let source: AnnotationSource
    let completed: (URL) -> Void
    let cancel: () -> Void
    var embedded = false
    var active = true
    var stateChanged: (Bool, Bool) -> Void = { _, _ in }

    @State private var annotations: [Annotation] = []
    @State private var selected: UUID?
    @State private var tool: AnnotationTool = .select
    @Namespace private var toolIndicator
    @State private var style = AnnotationStyle()
    @State private var page = 0
    @State private var backdrop: CGImage?
    @State private var signatures: [String: CGImage] = [:]
    @State private var editingText: UUID?
    @State private var textRequest: TextRequest?
    @State private var propertyCommit: Task<Void, Never>?
    @State private var adjustingRotation = false
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var signatureTarget: SignatureRequest?
    @State private var history = UndoStack<[Annotation]>([])
    @State private var zoom: Double?           // nil means fit to window
    @State private var confirmReset = false
    @State private var savedAnnotations: [Annotation] = []
    private let store = SignatureStore()
    private let accent = ReferenceStyle.accent
    private var complete: [Annotation] { annotations.complete(signatures: Set(signatures.keys)) }
    private var selectedAnnotation: Annotation? {
        selected.flatMap { id in annotations.first { $0.id == id } }
    }
    private var hasUnfinished: Bool { complete.count != annotations.count }

    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                if !embedded { ReferenceHeader(title: tr("editor.annotate"), close: cancel).disabled(saving) }
                toolbar.disabled(saving)
                // The row is always reserved: inserting it on selection shifted
                // and rescaled the canvas under the pointer, so a click followed
                // by a drag missed the handle it had just revealed.
                // Cross-fades in that fixed slot: nothing travels, nothing shifts.
                ZStack {
                    if let current = selectedAnnotation { propertyBar(current).transition(.opacity) }
                    else { Color.clear.frame(height: 28).padding(.bottom, 9) }
                }
                .motion(Motion.quick, value: selected)
                canvasArea.allowsHitTesting(!saving)
                if source.pageCount > 1 { pageStrip }
                if hasUnfinished {
                    Label(tr("editor.unfinished"), systemImage: "exclamationmark.circle")
                        .font(.system(size: 10)).foregroundStyle(accent)
                        .padding(.horizontal, 16).padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                if annotations.contains(where: { $0.kind.removesContent }) {
                    // The quality trade-off has to be said out loud.
                    Label(tr("editor.redactionWarning"), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10)).foregroundStyle(accent)
                        .padding(.horizontal, 16).padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                footer
            }
            .motion(Motion.smooth, value: hasUnfinished)
            .motion(Motion.smooth, value: annotations.contains(where: { $0.kind.removesContent }))
        }
        .frame(minWidth: embedded ? 0 : AnnotationLayout.minimum.width, maxWidth: .infinity,
               minHeight: embedded ? 0 : AnnotationLayout.minimum.height, maxHeight: .infinity)
        .task(id: page) { await loadPage() }
        .onAppear { signatures = store.load() }
        .onChange(of: selected) { _ in
            if editingText == nil && signatureTarget == nil,
               !annotations.contains(where: { !$0.isComplete(signatures: Set(signatures.keys)) }) { commitProperties() }
            if let annotation = selectedAnnotation { style = annotation.style }
        }
        .onChange(of: tool) { _ in commitProperties() }
        .onChange(of: page) { _ in selected = nil }
        .onDisappear { propertyCommit?.cancel() }
        .onChange(of: active) { value in if !value { commitProperties() } }
        .onChange(of: annotations) { _ in stateChanged(annotations != savedAnnotations, saving) }
        .onChange(of: saving) { _ in stateChanged(annotations != savedAnnotations, saving) }
        .disabled(!active)
        .background(EditorCommandBridge(active: active, commands: EditorWindowCommands(
            canUndo: { !saving && textRequest == nil && signatureTarget == nil && (history.canUndo || history.current != annotations) },
            canRedo: { !saving && textRequest == nil && signatureTarget == nil && history.canRedo },
            undo: undo, redo: redo, fit: { setZoom(nil) }, zoom: step, save: save))
            .frame(width: 0, height: 0).accessibilityHidden(true))
        .sheet(item: $signatureTarget) { target in
            SignatureCapture(store: store, accent: accent) { id in
                signatures = store.load()
                assignSignature(id, to: target.id)
            }
            // Closing without a choice must not leave an invisible element.
            .onDisappear { removeIfUnassigned(target.id) }
        }
        .sheet(item: $textRequest, onDismiss: cancelText) { request in
            AnnotationTextEntry(value: request.value, apply: { value in
                commitText(value)
                textRequest = nil
            }, cancel: {
                cancelText()
                textRequest = nil
            })
        }
        .alert(Text("editor.saveFailed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        // Discarding every element is not something to do on a single click.
        .alert(Text("editor.resetTitle"), isPresented: $confirmReset) {
            Button("editor.resetConfirm", role: .destructive) { apply([]) }
            Button("common.cancel", role: .cancel) { }
        } message: { Text("editor.resetMessage") }
    }

    /// The page keeps its aspect ratio; at fit it fills the area, otherwise it
    /// grows with the zoom and the scroll view takes over panning.
    private var canvasArea: some View {
        GeometryReader { geometry in
            let canvasSize = canvasSize(in: geometry.size)
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(backdrop: backdrop, annotations: $annotations, selected: $selected,
                                 signatures: signatures, logicalSize: logicalSize, tool: tool, style: style, page: page,
                                 requestsText: startTextEntry,
                                 requestsSignature: { signatureTarget = SignatureRequest(id: $0) },
                                 began: commitProperties,
                                 committed: { history.commitIfChanged($0) })
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
            }
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(.horizontal, 14)
    }

    /// Page size scaled to fit, then multiplied by the chosen zoom. Split out
    /// because the type checker gave up on it inside the view builder.
    private func canvasSize(in available: CGSize) -> CGSize {
        let width = Double(backdrop?.width ?? 1)
        let height = Double(backdrop?.height ?? 1)
        let usableWidth = max(available.width - 24, 50)
        let usableHeight = max(available.height - 16, 50)
        let fit = min(usableWidth / width, usableHeight / height)
        let factor = fit * (zoom ?? 1)
        return CGSize(width: width * factor, height: height * factor)
    }

    /// Names, not bare symbols: nobody guesses that a crossed-out eye redacts.
    private var toolbar: some View {
        HStack(spacing: 5) {
            ForEach(AnnotationTool.allCases) { item in toolButton(item) }
            Spacer()
        }
        .motion(Motion.snappy, value: tool)
        .padding(.horizontal, 16).padding(.vertical, 9)
    }
    private func toolButton(_ item: AnnotationTool) -> some View {
        let active = tool == item
        return Button { tool = item } label: {
            HStack(spacing: 4) {
                Image(systemName: item.symbol).font(.system(size: 11))
                Text(LocalizedStringKey(item.titleKey)).font(.system(size: 11))
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .foregroundStyle(active ? Color.white : ReferenceStyle.ink)
            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .background {
                // One accent shape slides to the chosen tool, by click or shortcut.
                if active {
                    RoundedRectangle(cornerRadius: 6).fill(accent)
                        .matchedGeometryEffect(id: "tool", in: toolIndicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ReferencePlainButton())
        .keyboardShortcut(item.shortcut, modifiers: [])
        .help(Text(tr(item.helpKey) + "  (" + item.shortcutLabel + ")"))
    }

    /// Element-specific controls. The toolbar above is already full, and these
    /// only make sense while something is selected.
    private func propertyBar(_ annotation: Annotation) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ColorPicker("editor.color", selection: Binding(
                    get: { Color(red: annotation.style.color.red, green: annotation.style.color.green, blue: annotation.style.color.blue) },
                    set: { value in
                        let ns = NSColor(value).usingColorSpace(.deviceRGB) ?? .orange
                        editSelected(continuous: true) { $0.style.color = RGB(ns.redComponent, ns.greenComponent, ns.blueComponent) }
                    }), supportsOpacity: false)
                    .labelsHidden().fixedSize().help(Text("help.annotationColor"))
                if case .text = annotation.kind {
                    Stepper(value: Binding(get: { annotation.style.fontSize }, set: { value in
                        editSelected { $0.style.fontSize = value }
                    }), in: 6...96, step: 2) {
                        Text(verbatim: "\(Int(annotation.style.fontSize)) pt").font(.system(size: 10)).monospacedDigit()
                    }.controlSize(.mini).fixedSize().help(Text("help.annotationSize"))
                }
                Text("editor.rotation").font(.system(size: 10)).fixedSize()
                Slider(value: Binding(get: { annotation.rotation }, set: { value in
                    editSelected(continuous: true) { $0.rotation = value }
                }), in: -180...180, onEditingChanged: { editing in
                    adjustingRotation = editing
                    if editing { propertyCommit?.cancel() } else { commitProperties() }
                }).controlSize(.mini).tint(accent).frame(width: 150)
                    .help(Text("help.rotation"))
                Text(verbatim: "\(Int(annotation.rotation))°").font(.system(size: 10)).monospacedDigit().fixedSize()
                Button("editor.rotationReset") { editSelected { $0.rotation = 0 } }
                    .buttonStyle(ReferenceActionButton())
                if case .text = annotation.kind {
                    Button("editor.changeText") { commitProperties(); startTextEntry(annotation.id) }
                        .buttonStyle(ReferenceActionButton()).help(Text("help.changeText"))
                }
                Button("editor.deleteElement") { deleteSelected() }
                    .buttonStyle(ReferenceActionButton()).help(Text("help.deleteElement"))
            }.padding(.horizontal, 16)
        }.frame(height: 28).padding(.bottom, 9).disabled(saving)
    }

    private var zoomControls: some View {
        HStack(spacing: 5) {
            Button { step(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(ReferencePlainButton(backdrop: true)).keyboardShortcut("-", modifiers: .command)
            Button("editor.zoomFit") { setZoom(nil) }
                .buttonStyle(ReferenceActionButton(primary: zoom == nil))
                .keyboardShortcut("0", modifiers: .command)
            Text(zoom == nil ? tr("editor.zoomFitShort") : "\(Int((zoom ?? 1) * 100)) %")
                .font(.system(size: 10)).monospacedDigit().frame(width: 52)
                .contentTransition(.opacity).motion(Motion.quick, value: zoom)
            Button { step(1) } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(ReferencePlainButton(backdrop: true)).keyboardShortcut("+", modifiers: .command)
        }.help(Text("help.zoom"))
    }

    private var pageStrip: some View {
        HStack(spacing: 8) {
            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(ReferencePlainButton(backdrop: true)).disabled(page == 0)
            Text(tr("editor.pageOf", page + 1, source.pageCount)).font(.system(size: 10)).monospacedDigit()
            Button { page = min(source.pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(ReferencePlainButton(backdrop: true)).disabled(page >= source.pageCount - 1)
            Spacer()
            Text(tr("editor.elementsOnPage", annotations.on(page: page).count))
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.horizontal, 16).padding(.top, 10)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ReferenceActionButton()).disabled(!history.canUndo)
                .help(Text("help.undo"))
            Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ReferenceActionButton()).disabled(!history.canRedo)
                .help(Text("help.redo"))
            Button("editor.reset") { commitProperties(); confirmReset = true }
                .buttonStyle(ReferenceActionButton()).disabled(annotations.isEmpty)
                .help(Text("help.resetEditor"))
            Spacer()
            zoomControls
            Spacer()
            if saving { ProgressView().controlSize(.small).transition(.opacity) }
            Button("editor.save", action: save)
                .buttonStyle(ReferenceActionButton(primary: true)).keyboardShortcut(.defaultAction)
                .disabled(complete.isEmpty).help(Text("help.saveEditor"))
        }
        .padding(13).disabled(saving)
        .motion(Motion.quick, value: saving)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
    }

    private var logicalSize: CGSize {
        switch source {
        case .image(let image): return CGSize(width: image.width, height: image.height)
        case .pdf(let document):
            guard let target = document.page(at: page) else { return .zero }
            let box = target.bounds(for: .mediaBox)
            return target.rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
        }
    }
    private func loadPage() async {
        switch source {
        case .image(let image): backdrop = image
        case .pdf(let document):
            let index = page
            do {
                let rendered = try await Task.detached(priority: .userInitiated) { () -> CGImage in
                    guard let target = document.page(at: index) else { throw ConversionError.unreadable }
                    return try FileConverter.render(target, dpi: 110)
                }.value
                guard !Task.isCancelled, page == index else { return }
                backdrop = rendered
            } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }
    private func startTextEntry(_ id: UUID) {
        guard let found = annotations.first(where: { $0.id == id }), case .text(let value) = found.kind else { return }
        editingText = id
        textRequest = TextRequest(id: id, value: value)
    }
    private func commitText(_ value: String) {
        guard let id = editingText else { return }
        apply(AnnotationEdits.text(annotations, id: id, value: value, committed: history.current))
        if !annotations.contains(where: { $0.id == selected }) { selected = nil }
        editingText = nil
    }
    private func cancelText() {
        guard let id = editingText else { return }
        annotations = AnnotationEdits.text(annotations, id: id, value: nil, committed: history.current)
        if !annotations.contains(where: { $0.id == selected }) { selected = nil }
        editingText = nil
    }
    /// Targeted, and only onto a signature: taking `selected` would turn a
    /// selected text element into a signature and lose what was typed.
    private func assignSignature(_ id: String, to target: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == target }),
              case .signature = annotations[index].kind else { return }
        annotations[index].kind = .signature(id: id)
        history.commitIfChanged(annotations)
    }
    private func removeIfUnassigned(_ target: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == target }),
              case .signature(let id) = annotations[index].kind, signatures[id] == nil else { return }
        annotations.remove(at: index)
        if selected == target { selected = nil }
    }
    private func editSelected(continuous: Bool = false, _ edit: (inout Annotation) -> Void) {
        guard let selected, let index = annotations.firstIndex(where: { $0.id == selected }) else { return }
        if !continuous { commitProperties() }
        edit(&annotations[index])
        style = annotations[index].style
        if !continuous { history.commitIfChanged(annotations); return }
        propertyCommit?.cancel()
        guard !adjustingRotation else { return }
        propertyCommit = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            history.commitIfChanged(annotations)
        }
    }
    private func commitProperties() {
        propertyCommit?.cancel()
        // A content frame exists before its dialog opens, but is not an edit yet.
        guard annotations.allSatisfy({ $0.isComplete(signatures: Set(signatures.keys)) }) else { return }
        history.commitIfChanged(annotations)
    }
    private func deleteSelected() {
        commitProperties()
        guard let selected else { return }
        apply(annotations.filter { $0.id != selected })
        self.selected = nil
    }
    /// Single place where a state change is both shown and recorded.
    private func apply(_ next: [Annotation]) {
        annotations = next
        propertyCommit?.cancel()
        history.commitIfChanged(next)
    }
    private func undo() {
        commitProperties()
        guard let previous = history.undo() else { return }
        annotations = previous
        if let selected, !previous.contains(where: { $0.id == selected }) { self.selected = nil }
    }
    private func redo() {
        commitProperties()
        guard let next = history.redo() else { return }
        annotations = next
        if let selected, !next.contains(where: { $0.id == selected }) { self.selected = nil }
    }
    private func step(_ direction: Int) {
        let steps = AnnotationLayout.zoomSteps
        let currentValue = zoom ?? 1
        if direction > 0 { setZoom(steps.first { $0 > currentValue + 0.001 } ?? steps.last) }
        else { setZoom(steps.last { $0 < currentValue - 0.001 } ?? steps.first) }
    }
    /// The page grows or shrinks into its new size instead of jumping to it.
    private func setZoom(_ next: Double?) {
        Motion.animate(Motion.snappy) { zoom = next }
    }

    private func save() {
        guard !saving, !complete.isEmpty else { return }
        commitProperties()
        saving = true
        // Only what is actually drawable; the rest would silently do nothing.
        let list = complete, images = signatures, input = file, origin = source
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { () -> URL in
                    switch origin {
                    case .image(let image):
                        let result = try AnnotationRenderer.render(list, on: image, signatures: images)
                        let data = try ImageConverter.encode(result, as: .png)
                        return try OutputWriter.write(data, beside: input, suffix: "annotated", extension: "png")
                    case .pdf(let document):
                        let data = try AnnotationRenderer.render(list, into: document, signatures: images)
                        return try OutputWriter.write(data, beside: input, suffix: "annotated", extension: "pdf")
                    }
                }.value
                saving = false
                savedAnnotations = list
                stateChanged(annotations != savedAnnotations, false)
                completed(output)
            } catch {
                saving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Owns one draft per presentation. Native alert text fields can reset their
/// binding while dismissing, so an existing annotation must not share it.
private struct AnnotationTextEntry: View {
    @State private var draft: String
    @FocusState private var focused: Bool
    let apply: (String) -> Void
    let cancel: () -> Void

    init(value: String, apply: @escaping (String) -> Void, cancel: @escaping () -> Void) {
        _draft = State(initialValue: value)
        self.apply = apply
        self.cancel = cancel
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("editor.textTitle").font(.headline)
            TextField("editor.textPlaceholder", text: $draft)
                .textFieldStyle(.roundedBorder).focused($focused)
            HStack {
                Spacer()
                Button("common.cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("editor.apply") { apply(draft) }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 380, height: 160)
        .onAppear { focused = true }
    }
}
