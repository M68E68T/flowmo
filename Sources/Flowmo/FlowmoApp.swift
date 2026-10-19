import AppKit
import SwiftUI
import PDFKit
import FlowmoCore

@main
enum FlowmoApp {
    @MainActor static func main() {
        // Build-time hook: renders the iconset from the same BrandMark vectors
        // the app draws with, so icon and interface can never drift apart.
        // Messages here stay plain: this is build output for a developer, and
        // the bare binary has no Bundle.main to resolve translations from.
        if CommandLine.arguments.contains("--export-iconset") {
            guard let index = CommandLine.arguments.firstIndex(of: "--export-iconset"),
                  index + 1 < CommandLine.arguments.count else {
                FileHandle.standardError.write(Data("--export-iconset braucht einen Zielordner.\n".utf8))
                exit(1)
            }
            exportIconset(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        let app = NSApplication.shared
        // Give the Dock the shared artwork even if it cached a placeholder
        // before the app bundle received its icon.
        app.applicationIconImage = BrandMark.image(side: 512, style: .appIcon)
        let controller = AppController()
        app.delegate = controller
        app.setActivationPolicy(.regular)
        withExtendedLifetime(controller) { app.run() }
    }

    /// The ten sizes `iconutil` expects, written as PNGs.
    @MainActor private static func exportIconset(to folder: URL) {
        let sizes = [16, 32, 128, 256, 512]
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for size in sizes {
                for scale in [1, 2] {
                    let pixels = size * scale
                    let suffix = scale == 1 ? "" : "@2x"
                    let image = BrandMark.image(side: CGFloat(pixels), style: .appIcon)
                    guard let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(using: .png, properties: [:]) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try png.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
                }
            }
            print("iconset: \(folder.path)")
        } catch {
            FileHandle.standardError.write(
                Data("Icon-Export fehlgeschlagen: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

/// Where an action was triggered. The floating wheel clears the screen
/// afterwards; a click inside the dashboard must not hide it under the cursor.
enum ActionOrigin { case floatingMenu, dashboard }

enum DashboardLayout { static let size = CGSize(width: 420, height: 550) }

@MainActor
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var selection: [URL] = []
    @Published var outputs: [URL] = []
    @Published var busy = false
    @Published var status = ""
    @Published var failure: String?
    @Published var tools = false
    @Published private(set) var preferences = Preferences.load()
    private let drag = GlobalDragController()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var introWindow: NSWindow?
    private var editors: [NSWindowController] = []
    private var statusItem: NSStatusItem?
    private var toast: NSPanel?
    private var closeObserver: NSObjectProtocol?
    private var launchedAtLogin = false

    var readyMessage: String { tr("status.ready", preferences.openCombo.symbols) }

    /// Stores the settings, applies them everywhere and keeps them for next launch.
    func commit(_ next: Preferences) {
        guard next.problem == nil else { return }
        preferences = next
        next.save()
        // Only the floating wheel is translucent; an open one follows along.
        drag.preferences = next
        if !busy, selection.isEmpty { status = readyMessage }
        updateMenu()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // The launch event is only current here, not after launching finished.
        launchedAtLogin = LoginItem.launchedAsLoginItem()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = readyMessage
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
            object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, let closed = notification.object as? NSWindow else { return }
                    self.editors.removeAll { $0.window === closed }
                    if self.settingsWindow === closed { self.settingsWindow = nil }
                    if self.introWindow === closed { self.introWindow = nil }
                }
            }
        drag.preferences = preferences
        drag.isBusy = { [weak self] in self?.busy ?? true }
        drag.perform = { [weak self] in self?.perform($0, files: $1, origin: .floatingMenu) }
        drag.report = { [weak self] in self?.status = $0 }
        let previewOnly = Bundle.main.object(forInfoDictionaryKey: "flowmoPreviewOnly") as? Bool == true
        if !previewOnly { drag.start() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = BrandMark.image(side: 18, style: .template)
        updateMenu(); installMainMenu()
        LoginItem.registerIfNeeded(previewOnly: previewOnly)
        // At login flowmo waits quietly in the menu bar; opened by hand it shows
        // the dashboard, and the first time the introduction, because nobody
        // guesses drag-plus-modifier on their own.
        let plan = LaunchPlan.make(launchedAtLogin: launchedAtLogin, introSeen: IntroState.hasSeen())
        if plan.showsDashboard { showMain() }
        if plan.showsIntroduction { showIntro() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    @objc func showMain() {
        if mainWindow == nil {
            let window = ReferenceWindow(size: DashboardLayout.size, title: "flowmo")
            window.identifier = NSUserInterfaceItemIdentifier("flowmo.main")
            window.contentViewController = NSHostingController(rootView: Dashboard(controller: self))
            window.center(); mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func hideMain() { mainWindow?.orderOut(nil) }
    /// Rebuilt on every open so the draft always starts from the stored state.
    /// Reusing the window would keep a discarded draft alive in @State.
    @objc func showSettings() {
        if let open = settingsWindow { open.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = ReferenceWindow(size:SettingsLayout.size,title:tr("settings.title"))
        window.identifier = NSUserInterfaceItemIdentifier("flowmo.settings")
        window.contentViewController = NSHostingController(rootView: SettingsView(controller: self))
        settingsWindow = window
        place(window)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    /// Rebuilt per open so it always starts on the first card.
    @objc func showIntro() {
        if let open = introWindow { open.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = ReferenceWindow(size: IntroLayout.size, title: tr("intro.title"))
        window.identifier = NSUserInterfaceItemIdentifier("flowmo.intro")
        window.contentViewController = NSHostingController(
            rootView: IntroView(controller: self, close: { [weak self] in self?.closeIntro() }))
        introWindow = window
        place(window)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func closeIntro() {
        introWindow?.close(); introWindow = nil
    }
    /// Nothing to undo: the window is rebuilt per open, so the draft always
    /// starts from the stored settings again.
    func closeSettings() {
        settingsWindow?.close(); settingsWindow = nil
    }
    /// Beside the dashboard while it is on screen, centred otherwise. Transparent
    /// windows would otherwise show through each other.
    private func place(_ window: NSWindow?) {
        guard let window else { return }
        // Assigning a hosting controller leaves a provisional size that only
        // grows to the real one after layout. Placing that would let the
        // grown window spill past the screen edge or onto its neighbour.
        if let reference = window as? ReferenceWindow { window.setContentSize(reference.preferredSize) }
        let candidates = [NSApp.keyWindow, mainWindow, settingsWindow, introWindow]
            + editors.reversed().map(\.window)
        guard let anchor = candidates.compactMap({ $0 }).first(where: { $0 !== window && $0.isVisible }) else {
            window.center(); return
        }
        let area = (anchor.screen ?? NSScreen.main)?.visibleFrame ?? anchor.frame
        let placed = WindowPlacement.pair(anchor.frame, size: window.frame.size, in: area)
        if placed.anchor != anchor.frame { anchor.setFrame(placed.anchor, display: true, animate: true) }
        window.setFrame(placed.window, display: false)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for owner in editors {
            guard let window = owner.window as? ReferenceWindow, window.isVisible,
                  let request = window.editorCloseRequest else { continue }
            if !request() { window.makeKeyAndOrderFront(nil); return .terminateCancel }
        }
        return .terminateNow
    }
    private func updateMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: tr("menu.open"), action: #selector(showMain), keyEquivalent: "o"); open.target = self; menu.addItem(open)
        let settings = NSMenuItem(title: tr("menu.settings"), action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let intro = NSMenuItem(title: tr("menu.intro"), action: #selector(showIntro), keyEquivalent: ""); intro.target = self; menu.addItem(intro)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: tr("menu.quit"), action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        statusItem?.menu = menu
    }
    private func installMainMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu(title: "flowmo")
        let quit = NSMenuItem(title: tr("menu.quit"), action: #selector(quit), keyEquivalent: "q"); quit.target = self
        appMenu.addItem(quit); appItem.submenu = appMenu; bar.addItem(appItem)
        let fileItem = NSMenuItem(); let fileMenu = NSMenu(title: tr("menu.file"))
        let choose = NSMenuItem(title: tr("menu.chooseFiles"), action: #selector(chooseFiles), keyEquivalent: "o"); choose.target = self
        fileMenu.addItem(choose)
        fileMenu.addItem(NSMenuItem(title: tr("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu; bar.addItem(fileItem)
        let editItem = NSMenuItem(); let editMenu = NSMenu(title: tr("menu.edit"))
        for (key, action, equivalent, modifiers) in [
            ("menu.undo", "undo:", "z", NSEvent.ModifierFlags.command),
            ("menu.redo", "redo:", "z", NSEvent.ModifierFlags([.command, .shift])),
            ("menu.cut", "cut:", "x", NSEvent.ModifierFlags.command),
            ("menu.copy", "copy:", "c", NSEvent.ModifierFlags.command),
            ("menu.paste", "paste:", "v", NSEvent.ModifierFlags.command),
            ("menu.selectAll", "selectAll:", "a", NSEvent.ModifierFlags.command)
        ] {
            let item = NSMenuItem(title: tr(key), action: Selector(action), keyEquivalent: equivalent)
            item.keyEquivalentModifierMask = modifiers
            editMenu.addItem(item)
            if key == "menu.redo" { editMenu.addItem(.separator()) }
        }
        editItem.submenu = editMenu; bar.addItem(editItem)
        NSApp.mainMenu = bar
    }
    @objc func chooseFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseFiles = true; panel.canChooseDirectories = false
        // Validate with ActionCatalog after selection. A broad picker also accepts
        // images whose imported UTType declaration is missing on this Mac.
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK { select(panel.urls) }
    }
    func select(_ urls: [URL]) {
        guard !busy else { return }
        selection = urls; outputs = []
        if ActionCatalog.actions(for: urls, tools: true).isEmpty { tools = false }
        if ActionCatalog.actions(for: urls, tools: false).isEmpty { status = tr("status.unsupportedSelection") }
        else { status = tr("status.selected", urls.count) }
    }
    func loadExample() {
        do { select([try makeExampleFile()]) } catch { failure = error.localizedDescription }
    }
    /// Shows the sample in Finder, so the first try is the real gesture: drag it
    /// with the trigger keys held, not a click inside flowmo.
    func revealExample() {
        do { NSWorkspace.shared.activateFileViewerSelecting([try makeExampleFile()]) }
        catch { failure = error.localizedDescription; showMain() }
    }
    private func makeExampleFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("flowmo-Beispiel-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let image = NSImage(size: CGSize(width: 960, height: 600))
        image.lockFocus()
        NSGradient(starting: .systemOrange, ending: .systemPink)?.draw(in: CGRect(x:0,y:0,width:960,height:600),angle:-30)
        NSColor.white.setFill(); NSBezierPath(roundedRect: CGRect(x:90,y:90,width:780,height:420),xRadius:28,yRadius:28).fill()
        (tr("sample.headline") as NSString).draw(at: CGPoint(x:140,y:330),withAttributes:[.font:NSFont.systemFont(ofSize:58,weight:.bold),.foregroundColor:NSColor.black])
        (tr("sample.subline") as NSString).draw(at: CGPoint(x:145,y:260),withAttributes:[.font:NSFont.systemFont(ofSize:28),.foregroundColor:NSColor.darkGray])
        image.unlockFocus()
        guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data:data), let png = bitmap.representation(using:.png,properties:[:]) else { throw ConversionError.encoding }
        let file = folder.appendingPathComponent("flowmo-Beispiel.png"); try png.write(to:file)
        return file
    }
    func perform(_ action: FileAction, files: [URL], origin: ActionOrigin = .dashboard) {
        guard !busy, !files.isEmpty else { return }
        selection = files; outputs = []; failure = nil
        if case .convert = action { tools = false } else { tools = true }
        switch action {
        case .convert(let format):
            busy = true; status = tr("status.creating", format.rawValue)
            Task {
                let report = await Task.detached(priority: .userInitiated) { () -> ([URL], [String]) in
                    var all: [URL] = [], errors: [String] = []
                    for file in files {
                        do { all.append(contentsOf: try FileConverter.convert(file, to: format)) }
                        catch { errors.append("\(file.lastPathComponent): \(error.localizedDescription)") }
                    }
                    return (all, errors)
                }.value
                outputs = report.0; busy = false
                status = report.0.isEmpty ? tr("status.none") : tr("status.saved", report.0.count)
                if !report.1.isEmpty { failure = report.1.joined(separator: "\n"); showMain() }
                // Clear the screen after a clean drop; errors must stay visible.
                if origin == .floatingMenu, report.1.isEmpty { hideMain() }
                showToast(report.1.isEmpty ? status : tr("status.convertedWithErrors"))
            }
        case .pages:
            guard let file = files.first, files.count == 1 else { return }
            busy = true; status = tr("status.loadingImage")
            Task {
                do {
                    let document = try await Task.detached(priority: .userInitiated) { try FileConverter.pdf(file) }.value
                    busy = false; openPageManager(file, document: document)
                    if origin == .floatingMenu { hideMain() }
                } catch { busy = false; failure = error.localizedDescription; showMain() }
            }
        case .annotate:
            guard let file = files.first, files.count == 1 else { return }
            if FileKind.detect(file) == .document {
                openAnnotationEditor(file, source: nil)
                if origin == .floatingMenu { hideMain() }
                return
            }
            busy = true; status = tr("status.loadingImage")
            Task {
                do {
                    let document = try await Task.detached(priority: .userInitiated) {
                        () -> AnnotationSource in
                        FileKind.detect(file) == .pdf
                            ? .pdf(try FileConverter.pdf(file))
                            : .image(try ImageConverter.decode(file))
                    }.value
                    busy = false; openAnnotationEditor(file, source: document)
                    if origin == .floatingMenu { hideMain() }
                } catch { busy = false; failure = error.localizedDescription; showMain() }
            }
        case .crop, .background, .compress:
            guard files.count == 1, let file = files.first else { return }
            busy = true; status = tr("status.loadingImage")
            Task {
                do {
                    let image = try await Task.detached(priority: .userInitiated) { try ImageConverter.decode(file) }.value
                    busy = false; openEditor(file, image: image, action: action)
                    if origin == .floatingMenu { hideMain() }
                } catch { busy = false; failure = error.localizedDescription; showMain() }
            }
        }
    }
    private func openAnnotationEditor(_ file: URL, source: AnnotationSource?) {
        let window = ReferenceWindow(size: AnnotationLayout.size, title: tr("document.title"), resizable: true)
        window.minSize = AnnotationLayout.minimum
        let editor = EditWorkspace(file: file, original: source, completed: { [weak self] output in
            self?.outputs = [output]; self?.status = tr("status.savedAs", output.lastPathComponent)
        }, close: { [weak window] in window?.close() })
        let hosting = NSHostingController(rootView: WindowSizedRoot(dimensions: window.dimensions, content: editor))
        hosting.sizingOptions = []
        window.contentViewController = hosting
        // Cascading would move the window again after `place` and undo it.
        let owner = NSWindowController(window: window); owner.shouldCascadeWindows = false; editors.append(owner)
        place(window)
        owner.showWindow(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        status = tr("status.opened", tr("editor.annotate"))
    }
    private func openPageManager(_ file: URL, document: PDFDocument) {
        let window = ReferenceWindow(size: PageManagerLayout.size, title: tr("pages.title"))
        let manager = PageManager(file: file, document: document, completed: { [weak self, weak window] output in
            self?.outputs = [output]; self?.status = tr("status.savedAs", output.lastPathComponent); window?.close()
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }, cancel: { [weak window] in window?.close() })
        window.contentViewController = NSHostingController(rootView: manager)
        let owner = NSWindowController(window: window); owner.shouldCascadeWindows = false; editors.append(owner)
        place(window)
        owner.showWindow(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        status = tr("status.opened", tr("pages.title"))
    }
    private func openEditor(_ file: URL, image: CGImage, action: FileAction) {
        let title = tr(action == .crop ? "editor.crop" : action == .background ? "editor.background" : "editor.compress")
        let window = ReferenceWindow(size:CGSize(width:action == .background ? 440:420,height:action == .background ? 660:640),title:title)
        let editor = ImageEditor(file: file, image: image, action: action, completed: { [weak self, weak window] output in
            self?.outputs = [output]; self?.status = tr("status.savedAs", output.lastPathComponent); window?.close()
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }, cancel: { [weak window] in window?.close() })
        window.contentViewController = NSHostingController(rootView: editor)
        let owner = NSWindowController(window: window); owner.shouldCascadeWindows = false; editors.append(owner)
        place(window)
        owner.showWindow(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        status = tr("status.opened", title)
    }
    /// Rises a few points while fading in and fades out on its own. A newer
    /// toast replaces the current one instead of stacking on top of it.
    private func showToast(_ text: String) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        if let previous = toast { dismissToast(previous) }
        let area = screen.visibleFrame
        let rest = CGRect(x: area.midX - 215, y: area.minY + 35, width: 430, height: 56)
        let rise: CGFloat = Motion.reduced ? 0 : 8
        let panel = NSPanel(contentRect: rest.offsetBy(dx: 0, dy: -rise), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.level = .floating; panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false; panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: ReferenceSurface { Text(text).font(.system(size:12,weight:.medium)).padding(16).frame(width:430,height:56) })
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        toast = panel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.Duration.present
            context.timingFunction = Motion.easeOut
            panel.animator().alphaValue = 1
            panel.animator().setFrame(rest, display: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.dismissToast(panel) }
    }
    private func dismissToast(_ panel: NSPanel) {
        if toast === panel { toast = nil }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Motion.Duration.fade
            context.timingFunction = Motion.easeIn
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }
}

struct Dashboard: View {
    @ObservedObject var controller: AppController
    private var hintLine: String {
        let open = controller.preferences.openCombo
        let tools = controller.preferences.toolsExtra
        guard !tools.isEmpty else { return tr("dashboard.legendNoTools", open.symbols) }
        return tr("dashboard.legend", open.symbols, open.union(tools).symbols)
    }
    var body: some View {
        ReferenceSurface {
            VStack(spacing:0) {
                ReferenceHeader(title:"flowmo",close:controller.hideMain)
                HStack {
                    Spacer()
                    if !ActionCatalog.actions(for: controller.selection, tools: true).isEmpty {
                        Toggle("dashboard.tools",isOn:$controller.tools).toggleStyle(.button).controlSize(.small)
                            .help(Text("help.tools")).transition(.opacity)
                    }
                    Button(action: controller.showSettings) {
                        Image(systemName:"gearshape").font(.system(size:11))
                    }.buttonStyle(ReferenceIconButton()).accessibilityLabel(Text("dashboard.settings"))
                        .help(Text("help.settings"))
                }.font(.system(size:11)).padding(.horizontal,18).padding(.top,13)
                ZStack {
                    if controller.selection.isEmpty {
                        Group {
                        Circle().strokeBorder(.black.opacity(0.08),lineWidth:0.7).frame(width:290,height:290)
                        VStack(spacing:14) {
                            Image(systemName:"doc").font(.system(size:38,weight:.ultraLight)).foregroundStyle(.secondary)
                            Text(tr("dashboard.dragHint", controller.preferences.openCombo.symbols)).font(.system(size:12))
                            // The empty circle is a drop target, not a button.
                            Text("dashboard.dropHint").font(.system(size:11)).foregroundStyle(.secondary)
                            Text(hintLine).font(.system(size:10)).foregroundStyle(.secondary)
                        }
                        }.transition(Motion.appear)
                    }
                    EmbeddedWheel(urls: controller.selection, tools: controller.tools,
                        action: { controller.perform($0, files: $1) }, receive: { controller.select($0) })
                }.frame(width:336,height:336).help(Text("help.wheel"))
                if let first = controller.selection.first {
                    Text(controller.selection.count == 1 ? first.lastPathComponent : tr("dashboard.fileCount", controller.selection.count))
                        .font(.system(size:10)).lineLimit(1).foregroundStyle(.secondary).padding(.horizontal,18)
                        .transition(.opacity)
                }
                if !controller.tools, controller.selection.first.map(FileKind.detect) == .pdf {
                    Text("dashboard.docxNote")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 18)
                        .transition(.opacity)
                }
                HStack(spacing: 7) {
                    if controller.busy { ProgressView().controlSize(.small).transition(.opacity) }
                    Text(controller.status).font(.system(size:10)).lineLimit(2)
                        .contentTransition(.opacity).motion(Motion.quick, value: controller.status)
                }.frame(minHeight:26).padding(.horizontal,18)
                Spacer(minLength: 0)
                HStack {
                    Button("dashboard.chooseFiles") { controller.chooseFiles() }.buttonStyle(ReferenceActionButton())
                        .help(Text("help.chooseFiles"))
                    Spacer()
                    if controller.outputs.isEmpty {
                        Button("dashboard.trySample") { controller.loadExample() }.buttonStyle(ReferenceActionButton(primary:true))
                            .help(Text("help.trySample")).transition(.opacity)
                    } else {
                        Button("dashboard.showInFinder") { NSWorkspace.shared.activateFileViewerSelecting(controller.outputs) }.buttonStyle(ReferenceActionButton(primary:true))
                            .help(Text("help.showInFinder")).transition(.opacity)
                    }
                }.padding(13).disabled(controller.busy)
                    .overlay(alignment:.top) { Rectangle().fill(.black.opacity(0.075)).frame(height:0.6) }
            }
        }
        // State changes arrive from the controller; the view decides how they move.
        .motion(Motion.smooth, value: controller.selection)
        .motion(Motion.smooth, value: controller.tools)
        .motion(Motion.quick, value: controller.outputs)
        .motion(Motion.quick, value: controller.busy)
        .frame(width: DashboardLayout.size.width, height: DashboardLayout.size.height)
        .alert("flowmo", isPresented: Binding(get: { controller.failure != nil }, set: { if !$0 { controller.failure = nil } })) {
            Button("common.ok") { controller.failure = nil }
        } message: { Text(controller.failure ?? "") }
    }
}
