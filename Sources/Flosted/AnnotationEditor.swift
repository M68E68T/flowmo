import AppKit
import SwiftUI
import PDFKit
import FlostedCore

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

struct AnnotationEditor: View {
    let file: URL
    let source: AnnotationSource
    let completed: (URL) -> Void
    let cancel: () -> Void

    @State private var annotations: [Annotation] = []
    @State private var selected: UUID?
    @State private var tool: AnnotationTool = .select
    @State private var style = AnnotationStyle()
    @State private var page = 0
    @State private var backdrop: CGImage?
    @State private var signatures: [String: CGImage] = [:]
    @State private var editingText: UUID?
    @State private var textDraft = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var signatureTarget: SignatureRequest?
    @State private var history = UndoStack<[Annotation]>([])
    @State private var zoom: Double?           // nil means fit to window
    @State private var confirmReset = false
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
                ReferenceHeader(title: tr("editor.annotate"), close: cancel)
                toolbar
                if let current = selectedAnnotation { propertyBar(current) }
                canvasArea
                if source.pageCount > 1 { pageStrip }
                if hasUnfinished {
                    Label(tr("editor.unfinished"), systemImage: "exclamationmark.circle")
                        .font(.system(size: 10)).foregroundStyle(accent)
                        .padding(.horizontal, 16).padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if annotations.contains(where: { $0.kind.removesContent }) {
                    // The quality trade-off has to be said out loud.
                    Label(tr("editor.redactionWarning"), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10)).foregroundStyle(accent)
                        .padding(.horizontal, 16).padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                footer
            }
        }
        .frame(minWidth: AnnotationLayout.minimum.width, maxWidth: .infinity,
               minHeight: AnnotationLayout.minimum.height, maxHeight: .infinity)
        .task { await loadPage() }
        .task(id: page) { await loadPage() }
        .onAppear { signatures = store.load() }
        .sheet(item: $signatureTarget) { target in
            SignatureCapture(store: store, accent: accent) { id in
                signatures = store.load()
                assignSignature(id, to: target.id)
            }
            // Closing without a choice must not leave an invisible element.
            .onDisappear { removeIfUnassigned(target.id) }
        }
        .alert(Text("editor.textTitle"), isPresented: Binding(get: { editingText != nil }, set: { if !$0 { editingText = nil } })) {
            TextField("editor.textPlaceholder", text: $textDraft)
            Button("editor.apply") { commitText() }
            // textDraft is empty here, so commitText drops the empty element.
            Button("common.cancel", role: .cancel) { textDraft = ""; commitText() }
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
                                 signatures: signatures, tool: tool, style: style, page: page,
                                 requestsText: startTextEntry,
                                 requestsSignature: { signatureTarget = SignatureRequest(id: $0) },
                                 committed: { history.commit($0) })
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
            .background(active ? accent : Color.black.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(item.shortcut, modifiers: [])
        .help(Text(tr(item.helpKey) + "  (" + item.shortcutLabel + ")"))
    }

    /// Element-specific controls. The toolbar above is already full, and these
    /// only make sense while something is selected.
    private func propertyBar(_ annotation: Annotation) -> some View {
        HStack(spacing: 10) {
            ColorPicker("editor.color", selection: Binding(
                get: { Color(red: style.color.red, green: style.color.green, blue: style.color.blue) },
                set: { newValue in
                    let ns = NSColor(newValue).usingColorSpace(.deviceRGB) ?? .orange
                    style.color = RGB(ns.redComponent, ns.greenComponent, ns.blueComponent)
                    applyStyleToSelection()
                }), supportsOpacity: false)
                .labelsHidden().frame(width: 26).help(Text("help.annotationColor"))
            if case .text = annotation.kind {
                Stepper(value: $style.fontSize, in: 6...96, step: 2) {
                    Text(verbatim: "\(Int(style.fontSize)) pt").font(.system(size: 10)).monospacedDigit()
                }.controlSize(.mini).onChange(of: style.fontSize) { _ in applyStyleToSelection() }
                    .help(Text("help.annotationSize"))
            }
            Text("editor.rotation").font(.system(size: 10)).fixedSize()
            Slider(value: Binding(
                get: { annotation.rotation },
                set: { newValue in
                    guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
                    annotations[index].rotation = newValue
                }), in: -180...180)
                .controlSize(.mini).tint(accent).frame(maxWidth: 190)
            Text(verbatim: "\(Int(annotation.rotation))°")
                .font(.system(size: 10)).monospacedDigit().fixedSize()
            Button("editor.rotationReset") {
                guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
                annotations[index].rotation = 0
            }.buttonStyle(ReferenceActionButton())
            if case .text = annotation.kind {
                Button("editor.changeText") { startTextEntry(annotation.id) }
                    .buttonStyle(ReferenceActionButton()).help(Text("help.changeText"))
            }
            Spacer()
            Button("editor.deleteElement") { deleteSelected() }
                .buttonStyle(ReferenceActionButton()).help(Text("help.deleteElement"))
        }
        .padding(.horizontal, 16).padding(.bottom, 9)
    }

    private var zoomControls: some View {
        HStack(spacing: 5) {
            Button { step(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(.plain).keyboardShortcut("-", modifiers: .command)
            Button("editor.zoomFit") { zoom = nil }
                .buttonStyle(ReferenceActionButton(primary: zoom == nil))
                .keyboardShortcut("0", modifiers: .command)
            Text(zoom == nil ? tr("editor.zoomFitShort") : "\(Int((zoom ?? 1) * 100)) %")
                .font(.system(size: 10)).monospacedDigit().frame(width: 52)
            Button { step(1) } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(.plain).keyboardShortcut("+", modifiers: .command)
        }.help(Text("help.zoom"))
    }

    private var pageStrip: some View {
        HStack(spacing: 8) {
            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain).disabled(page == 0)
            Text(tr("editor.pageOf", page + 1, source.pageCount)).font(.system(size: 10)).monospacedDigit()
            Button { page = min(source.pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain).disabled(page >= source.pageCount - 1)
            Spacer()
            Text(tr("editor.elementsOnPage", annotations.on(page: page).count))
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.horizontal, 16).padding(.top, 10)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ReferenceActionButton()).disabled(!history.canUndo)
                .keyboardShortcut("z", modifiers: .command).help(Text("help.undo"))
            Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ReferenceActionButton()).disabled(!history.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift]).help(Text("help.redo"))
            Button("editor.reset") { confirmReset = true }
                .buttonStyle(ReferenceActionButton()).disabled(annotations.isEmpty)
                .help(Text("help.resetEditor"))
            Spacer()
            zoomControls
            Spacer()
            if saving { ProgressView().controlSize(.small) }
            Button("editor.save", action: save)
                .buttonStyle(ReferenceActionButton(primary: true)).keyboardShortcut(.defaultAction)
                .disabled(complete.isEmpty).help(Text("help.saveEditor"))
        }
        .padding(13).disabled(saving)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
    }

    private func loadPage() async {
        switch source {
        case .image(let image): backdrop = image
        case .pdf(let document):
            let index = page
            backdrop = try? await Task.detached(priority: .userInitiated) { () -> CGImage? in
                guard let target = document.page(at: index) else { return nil }
                return try FileConverter.render(target, dpi: 110)
            }.value
        }
    }
    private func startTextEntry(_ id: UUID) {
        if let found = annotations.first(where: { $0.id == id }), case .text(let value) = found.kind {
            textDraft = value
        } else { textDraft = "" }
        editingText = id
    }
    private func commitText() {
        guard let id = editingText, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        // An empty text would leave an invisible element behind.
        var next = annotations
        if textDraft.isEmpty { next.remove(at: index) } else { next[index].kind = .text(textDraft) }
        apply(next)
        editingText = nil
    }
    /// Targeted, and only onto a signature: taking `selected` would turn a
    /// selected text element into a signature and lose what was typed.
    private func assignSignature(_ id: String, to target: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == target }),
              case .signature = annotations[index].kind else { return }
        annotations[index].kind = .signature(id: id)
        history.commit(annotations)
    }
    private func removeIfUnassigned(_ target: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == target }),
              case .signature(let id) = annotations[index].kind, signatures[id] == nil else { return }
        annotations.remove(at: index)
    }
    private func applyStyleToSelection() {
        guard let selected, let index = annotations.firstIndex(where: { $0.id == selected }) else { return }
        annotations[index].style = style
    }
    private func deleteSelected() {
        guard let selected else { return }
        apply(annotations.filter { $0.id != selected })
        self.selected = nil
    }
    /// Single place where a state change is both shown and recorded.
    private func apply(_ next: [Annotation]) {
        annotations = next
        history.commit(next)
    }
    private func undo() {
        guard let previous = history.undo() else { return }
        annotations = previous
        if let selected, !previous.contains(where: { $0.id == selected }) { self.selected = nil }
    }
    private func redo() {
        guard let next = history.redo() else { return }
        annotations = next
        if let selected, !next.contains(where: { $0.id == selected }) { self.selected = nil }
    }
    private func step(_ direction: Int) {
        let steps = AnnotationLayout.zoomSteps
        let currentValue = zoom ?? 1
        if direction > 0 { zoom = steps.first { $0 > currentValue + 0.001 } ?? steps.last }
        else { zoom = steps.last { $0 < currentValue - 0.001 } ?? steps.first }
    }

    private func save() {
        guard !saving else { return }
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
                completed(output)
            } catch {
                saving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
