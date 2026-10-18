import AppKit
import SwiftUI
import PDFKit
import FlostedCore

enum PageManagerLayout { static let size = CGSize(width: 680, height: 640) }

/// One thumbnail. Identity is the page object, so reordering keeps selection
/// and previews attached to the right page.
private struct PageThumb: Identifiable {
    let id: ObjectIdentifier
    let page: PDFPage
    var preview: NSImage?
    init(_ page: PDFPage) { self.id = ObjectIdentifier(page); self.page = page }
}

struct PageManager: View {
    let file: URL
    let document: PDFDocument
    let completed: (URL) -> Void
    let cancel: () -> Void

    @State private var thumbs: [PageThumb] = []
    @State private var selection: Set<ObjectIdentifier> = []
    @State private var dragging: ObjectIdentifier?
    @State private var hovered: ObjectIdentifier?
    @State private var beforeDrag: [PageThumb]?
    @State private var importing = false
    @State private var importTask: Task<Void, Never>?
    @State private var previewGeneration = UUID()
    @State private var isOpen = true
    @State private var importTargeted = false
    @State private var saving = false
    @State private var errorMessage: String?
    private let accent = ReferenceStyle.accent
    private let columns = [GridItem(.adaptive(minimum: 116), spacing: 14)]

    /// The thumbnails are the source of truth: they may have been reordered,
    /// trimmed or extended, so document indices no longer line up.
    private var selectedPages: [PDFPage] {
        thumbs.filter { selection.contains($0.id) }.map(\.page)
    }

    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                ReferenceHeader(title: tr("pages.title"), close: cancel).disabled(saving)
                toolbar.disabled(saving || importing)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(thumbs) { thumb in thumbnail(thumb) }
                    }.padding(16)
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .top)
                }
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(importTargeted ? accent : .clear, lineWidth: 2))
                .onDrop(of: [.fileURL], isTargeted: $importTargeted) { providers in
                    guard !saving, !importing else { return false }
                    receive(providers, nil)   // free area: append
                    return true
                }
                .padding(.horizontal, 14)
                Text("pages.dropHint").font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.top, 6)
                footer
            }
        }
        .frame(width: PageManagerLayout.size.width, height: PageManagerLayout.size.height)
        .task { isOpen = true; await reload() }
        .onDisappear {
            isOpen = false; importTask?.cancel(); previewGeneration = UUID()
            dragging = nil; hovered = nil; beforeDrag = nil
        }
        .alert(Text("editor.saveFailed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var toolbar: some View {
        HStack(spacing: 7) {
            Button("pages.rotateLeft") { rotate(-90) }.buttonStyle(ReferenceActionButton())
                .disabled(selection.isEmpty).help(Text("help.pagesRotate"))
            Button("pages.rotateRight") { rotate(90) }.buttonStyle(ReferenceActionButton())
                .disabled(selection.isEmpty).help(Text("help.pagesRotate"))
            Button("pages.delete") { deleteSelected() }.buttonStyle(ReferenceActionButton())
                .disabled(selection.isEmpty || selection.count >= thumbs.count)
                .help(Text("help.pagesDelete"))
            Divider().frame(height: 18)
            Button("pages.append") { appendDocument() }.buttonStyle(ReferenceActionButton())
                .help(Text("help.pagesAppend"))
            Spacer()
            Text(tr("pages.count", thumbs.count)).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func thumbnail(_ thumb: PageThumb) -> some View {
        let index = thumbs.firstIndex { $0.id == thumb.id }
        let isSelected = selection.contains(thumb.id)
        return VStack(spacing: 5) {
            ZStack {
                if let preview = thumb.preview {
                    Image(nsImage: preview).resizable().scaledToFit()
                } else { ProgressView().controlSize(.small) }
            }
            .frame(width: 104, height: 132)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? accent : .black.opacity(0.14), lineWidth: isSelected ? 2 : 0.7))
            Text(verbatim: "\((index ?? 0) + 1)").font(.system(size: 10)).monospacedDigit()
                .foregroundStyle(isSelected ? accent : .secondary)
        }
        .contentShape(Rectangle())
        .overlay(PageDragSource(image: thumb.preview, label: tr("pages.page", (index ?? 0) + 1),
                                token: thumb.id.debugDescription, selected: isSelected,
            clicked: { flags in
                if flags.contains(.shift) || flags.contains(.command) {
                    if selection.contains(thumb.id) { selection.remove(thumb.id) } else { selection.insert(thumb.id) }
                } else { selection = [thumb.id] }
            }, began: { beforeDrag = thumbs; dragging = thumb.id }, ended: { accepted in
                if !accepted, let original = beforeDrag { thumbs = original }
                dragging = nil; hovered = nil; beforeDrag = nil
            }))
        .allowsHitTesting(!saving && !importing)
        // One delegate for both: SwiftUI allows only a single drop modifier
        // per view, and reordering plus importing share this target.
        .onDrop(of: [.text, .fileURL],
                delegate: ThumbDropDelegate(target: thumb.id, dragging: $dragging, hovered: $hovered,
                                            thumbs: $thumbs, receive: receive))
        .help(Text("help.pagesReorder"))
    }

    private var footer: some View {
        HStack {
            Button("pages.selectAll") { selection = Set(thumbs.map(\.id)) }.buttonStyle(ReferenceActionButton())
            Spacer()
            if saving || importing { ProgressView().controlSize(.small) }
            Button("editor.save", action: save).buttonStyle(ReferenceActionButton(primary: true))
                .keyboardShortcut(.defaultAction).help(Text("help.saveEditor"))
        }
        .padding(13).disabled(saving || importing)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
    }

    private func reload() async {
        thumbs = (0..<document.pageCount).compactMap { document.page(at: $0).map(PageThumb.init) }
        refreshPreviews()
    }
    /// PDFKit's own thumbnail honours page rotation and caches internally, so
    /// this stays on the main actor instead of shipping pages across threads.
    private func refreshPreviews() {
        let size = CGSize(width: 104, height: 132)
        let generation = UUID(); previewGeneration = generation
        let ids = thumbs.map(\.id)
        Task { @MainActor in
            for id in ids {
                guard isOpen, previewGeneration == generation else { return }
                if let index = thumbs.firstIndex(where: { $0.id == id }) {
                    thumbs[index].preview = thumbs[index].page.thumbnail(of: size, for: .mediaBox)
                }
                // PDFKit stays on the main actor, but a large document must not
                // monopolize it for every thumbnail in one synchronous loop.
                await Task.yield()
            }
        }
    }
    private func rotate(_ degrees: Int) {
        PageOperations.rotate(selectedPages, by: degrees)
        // Rotation lives on the page object; only the previews need redrawing.
        refreshPreviews()
    }
    private func deleteSelected() {
        let keep = thumbs.filter { !selection.contains($0.id) }
        guard !keep.isEmpty else { return }
        thumbs = keep
        selection = []
    }
    private func appendDocument() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        insert(panel.urls, at: nil)
    }

    /// Resolves the dropped providers, then hands the urls to `insert`.
    private func receive(_ providers: [NSItemProvider], _ index: Int?) {
        let group = DispatchGroup()
        var urls: [Int: URL] = [:]
        let lock = NSLock()
        for (index, provider) in providers.enumerated() {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { lock.lock(); urls[index] = url; lock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) { if isOpen { insert(urls.keys.sorted().compactMap { urls[$0] }, at: index) } }
    }

    /// Unreadable files are collected rather than aborting the whole drop:
    /// one odd file must not cost the user the rest of the selection.
    private func insert(_ urls: [URL], at index: Int?) {
        guard isOpen, !urls.isEmpty, !saving, !importing else { return }
        importing = true
        importTask = Task { @MainActor in
            let report = await Task.detached(priority: .userInitiated) { () -> ([PDFPage], [String]) in
                var pages: [PDFPage] = [], failed: [String] = []
                for url in urls {
                    do { pages.append(contentsOf: try PageOperations.pages(from: url)) }
                    catch { failed.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                }
                return (pages, failed)
            }.value
            guard !Task.isCancelled, isOpen else { return }
            let added = report.0.map(PageThumb.init)
            if !added.isEmpty {
                let at = min(max(index ?? thumbs.count, 0), thumbs.count)
                thumbs.insert(contentsOf: added, at: at)
                selection = Set(added.map(\.id))
                refreshPreviews()
            }
            importing = false
            if !report.1.isEmpty { errorMessage = report.1.joined(separator: "\n") }
        }
    }

    private func save() {
        guard !saving, !importing, !thumbs.isEmpty else { return }
        saving = true
        // Rebuild from the thumbnails: they carry the order shown on screen.
        let pages = thumbs.map(\.page), input = file
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { () -> URL in
                    let result = PDFDocument()
                    for (index, page) in pages.enumerated() {
                        guard let copy = page.copy() as? PDFPage else { throw ConversionError.encoding }
                        result.insert(copy, at: index)
                    }
                    return try OutputWriter.write(try PageOperations.data(result), beside: input,
                                                  suffix: "pages", extension: "pdf")
                }.value
                saving = false
                completed(output)
            } catch { saving = false; errorMessage = error.localizedDescription }
        }
    }
}

/// Reorders while dragging so the grid shows the result before dropping, and
/// accepts dropped files, inserting their pages before this thumbnail.
private struct ThumbDropDelegate: DropDelegate {
    let target: ObjectIdentifier
    @Binding var dragging: ObjectIdentifier?
    @Binding var hovered: ObjectIdentifier?
    @Binding var thumbs: [PageThumb]
    let receive: ([NSItemProvider], Int?) -> Void

    func dropEntered(info: DropInfo) {
        hovered = target
        guard !info.hasItemsConforming(to: [.fileURL]), let dragging, dragging != target,
              let from = thumbs.firstIndex(where: { $0.id == dragging }),
              let to = thumbs.firstIndex(where: { $0.id == target }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            thumbs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.fileURL]) || dragging != nil else { return false }
        if info.hasItemsConforming(to: [.fileURL]) {
            receive(info.itemProviders(for: [.fileURL]), thumbs.firstIndex { $0.id == target })
        }
        dragging = nil; hovered = nil
        return true
    }
    // Leaving one thumbnail is not the end of the drag: it may enter the next.
    // Clear target state here; the native source clears/restores the session on
    // EVERY end, including Escape and a release outside all thumbnails.
    func dropExited(info: DropInfo) { if hovered == target { hovered = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: info.hasItemsConforming(to: [.fileURL]) ? .copy : .move)
    }
}
