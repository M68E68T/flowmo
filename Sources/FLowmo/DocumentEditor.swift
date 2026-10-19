import AppKit
import SwiftUI
import FLowmoCore

struct DocumentEditor: View {
    let file: URL
    @ObservedObject var model: DocumentEditorModel
    let active: Bool
    private let families = NSFontManager.shared.availableFontFamilies.sorted()
    private let sizeFormatter: NumberFormatter = {
        let value = NumberFormatter(); value.numberStyle = .decimal; value.maximumFractionDigits = 1
        value.minimum = 6; value.maximum = 144; return value
    }()

    var body: some View {
        VStack(spacing: 0) {
            if model.layout != nil {
                formatting.disabled(model.saving)
                Text("document.layoutNote").font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 8)
                DocumentPages(model: model, active: active).padding(.horizontal, 14)
                    .allowsHitTesting(!model.saving)
                if model.usedOCR {
                    Label("document.ocrNote", systemImage: "text.viewfinder")
                        .font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 7)
                }
                if let message = model.message {
                    Text(verbatim: message).font(.system(size: 11)).foregroundStyle(.red)
                        .padding(.horizontal, 16).padding(.top, 7).textSelection(.enabled)
                }
                footer
            } else {
                Spacer()
                if model.loading {
                    ProgressView(value: model.progress).frame(width: 220).tint(ReferenceStyle.accent)
                    Text("document.importing").font(.system(size: 12)).padding(.top, 8)
                    Button("common.cancel") { model.cancelImport() }
                        .buttonStyle(ReferenceActionButton()).padding(.top, 12)
                } else {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text(verbatim: model.message ?? tr("document.importing"))
                        .font(.system(size: 12)).multilineTextAlignment(.center).frame(maxWidth: 360).padding(12)
                    Button("document.retry") { Task { await model.load(file) } }.buttonStyle(ReferenceActionButton())
                }
                Spacer()
            }
        }
        .disabled(!active)
        .background(EditorCommandBridge(active: active, commands: EditorWindowCommands(
            canUndo: { !model.saving && model.canUndo }, canRedo: { !model.saving && model.canRedo },
            undo: model.undo, redo: model.redo, fit: { model.zoom = nil }, zoom: model.stepZoom,
            save: { model.save(beside: file) }))
            .frame(width: 0, height: 0).accessibilityHidden(true))
    }

    private var formatting: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Picker("document.font", selection: Binding(get: { model.font.familyName ?? "Helvetica" }, set: model.setFontFamily)) {
                    ForEach(families, id: \.self) { Text(verbatim: $0).tag($0) }
                }.labelsHidden().frame(width: 170).help(Text("document.font"))
                TextField("document.fontSize", value: Binding(get: { Double(model.font.pointSize) }, set: model.setFontSize), formatter: sizeFormatter)
                    .frame(width: 48).textFieldStyle(.roundedBorder).help(Text("document.fontSize"))
                emphasis("bold", key: "document.bold", selected: model.bold, action: model.toggleBold)
                emphasis("italic", key: "document.italic", selected: model.italic, action: model.toggleItalic)
                emphasis("underline", key: "document.underline", selected: model.underlined, action: model.toggleUnderline)
                ColorPicker("document.color", selection: Binding(get: { Color(nsColor: model.color) }, set: { model.setColor(NSColor($0)) }), supportsOpacity: false)
                    .labelsHidden().fixedSize().help(Text("document.color"))
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                alignment(.left, symbol: "text.alignleft", key: "document.alignLeft")
                alignment(.center, symbol: "text.aligncenter", key: "document.alignCenter")
                alignment(.right, symbol: "text.alignright", key: "document.alignRight")
                alignment(.justified, symbol: "text.justify", key: "document.alignJustified")
                Menu {
                    Button("document.listNone") { model.setList(.none) }
                    Button("document.listBullet") { model.setList(.bullet) }
                    Button("document.listNumbered") { model.setList(.numbered) }
                } label: { Label("document.list", systemImage: "list.bullet") }
                    .menuStyle(.borderlessButton).frame(width: 110).help(Text("document.list"))
                Spacer()
                Text(tr("document.pageCount", model.layout?.containers.count ?? 1))
                    .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .controlSize(.small).font(.system(size: 11))
        .padding(.horizontal, 16).padding(.vertical, 9)
    }
    private func emphasis(_ symbol: String, key: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 14) }
            .buttonStyle(ReferenceActionButton(primary: selected))
            .accessibilityLabel(Text(LocalizedStringKey(key))).help(Text(LocalizedStringKey(key)))
    }
    private func alignment(_ alignment: NSTextAlignment, symbol: String, key: String) -> some View {
        emphasis(symbol, key: key, selected: model.alignment == alignment) { model.setAlignment(alignment) }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let output = model.lastOutput {
                Text(tr("status.savedAs", output.lastPathComponent)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 8) {
                Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(ReferenceActionButton()).disabled(!model.canUndo).help(Text("help.undo"))
                Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }
                    .buttonStyle(ReferenceActionButton()).disabled(!model.canRedo).help(Text("help.redo"))
                Spacer()
                Button { model.stepZoom(-1) } label: { Image(systemName: "minus.magnifyingglass") }.buttonStyle(.plain).help(Text("help.zoom"))
                Button("editor.zoomFit") { model.zoom = nil }.buttonStyle(ReferenceActionButton(primary: model.zoom == nil)).help(Text("help.zoom"))
                Text(model.zoom.map { "\(Int($0 * 100)) %" } ?? tr("editor.zoomFitShort"))
                    .font(.system(size: 10)).monospacedDigit().frame(width: 50)
                Button { model.stepZoom(1) } label: { Image(systemName: "plus.magnifyingglass") }.buttonStyle(.plain).help(Text("help.zoom"))
                Spacer()
                Picker("document.outputFormat", selection: $model.outputFormat) {
                    Text(verbatim: "PDF").tag(OutputFormat.pdf)
                    Text(verbatim: "DOCX").tag(OutputFormat.docx)
                }.labelsHidden().frame(width: 80).help(Text("document.outputFormat"))
                if model.saving { ProgressView().controlSize(.small) }
                Button("editor.save") { model.save(beside: file) }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(ReferenceActionButton(primary: true)).disabled(!model.canSave).help(Text("help.saveEditor"))
            }
        }.padding(13).disabled(model.saving)
    }
}

struct EditWorkspace: View {
    let file: URL
    let original: AnnotationSource?
    let completed: (URL) -> Void
    let close: () -> Void
    @StateObject private var document = DocumentEditorModel()
    @State private var originalMode = false
    @State private var originalDirty = false
    @State private var originalSaving = false
    @State private var originalOutput: URL?
    @State private var confirmClose = false

    private var busy: Bool { document.saving || originalSaving }
    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                ReferenceHeader(title: tr("document.title"), close: { if requestClose() { close() } }).disabled(busy)
                if original != nil {
                    ReferenceSegments(values: [(tr("document.textMode"), 0), (tr("document.originalMode"), 1)],
                                      selection: Binding(get: { originalMode ? 1 : 0 }, set: { originalMode = $0 == 1 }))
                        .frame(width: 340).padding(.bottom, 9).disabled(busy)
                        .help(Text("document.mode"))
                        .onChange(of: originalMode) { _ in
                            document.activeTextView?.unmarkText(); document.flushTyping()
                            if let view = document.activeTextView {
                                view.window?.makeFirstResponder(originalMode ? nil : view)
                            }
                        }
                }
                // Both branches keep their drafts and histories when hidden.
                // Inactive command bridges and shortcuts must relinquish input.
                ZStack {
                    DocumentEditor(file: file, model: document, active: !originalMode)
                        .opacity(originalMode ? 0 : 1).allowsHitTesting(!originalMode).accessibilityHidden(originalMode)
                    if let original {
                        AnnotationEditor(file: file, source: original, completed: { output in
                            originalOutput = output; completed(output)
                        }, cancel: {},
                                         embedded: true, active: originalMode,
                                         stateChanged: { originalDirty = $0; originalSaving = $1 })
                            .opacity(originalMode ? 1 : 0).allowsHitTesting(originalMode).accessibilityHidden(!originalMode)
                    }
                }
                if originalMode, let output = originalOutput {
                    Text(tr("status.savedAs", output.lastPathComponent)).font(.system(size: 10))
                        .foregroundStyle(.secondary).lineLimit(1).padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
        .task { document.completed = completed; await document.load(file) }
        .onDisappear { document.cancelImport() }
        .background(EditorCloseBridge(shouldClose: requestClose).frame(width: 0, height: 0))
        .alert(Text("document.unsavedTitle"), isPresented: $confirmClose) {
            Button("document.keepEditing", role: .cancel) { }
            Button("document.discard", role: .destructive) { document.cancelImport(); close() }
        } message: { Text("document.unsavedMessage") }
    }
    private func requestClose() -> Bool {
        guard !busy else { return false }
        document.activeTextView?.unmarkText(); document.flushTyping()
        if document.dirty || originalDirty { confirmClose = true; return false }
        return true
    }
}
