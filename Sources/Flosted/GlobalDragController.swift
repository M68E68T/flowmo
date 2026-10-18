import AppKit
import FlostedCore

extension ModifierCombo {
    /// Bridge from AppKit so FlostedCore stays testable without AppKit events.
    init(_ flags: NSEvent.ModifierFlags) {
        var combo = ModifierCombo()
        if flags.contains(.shift) { combo.insert(.shift) }
        if flags.contains(.control) { combo.insert(.control) }
        if flags.contains(.option) { combo.insert(.option) }
        if flags.contains(.command) { combo.insert(.command) }
        self = combo
    }
}

/// Reads only the public drag pasteboard, pressed mouse buttons and modifier flags.
/// Does not install a keyboard hook, capture the screen or use Accessibility APIs.
@MainActor
final class GlobalDragController {
    var preferences = Preferences.default { didSet { applyOpacity() } }
    var isBusy: () -> Bool = { false }
    var perform: ((FileAction, [URL]) -> Void)?
    var report: ((String) -> Void)?
    private let pasteboard = NSPasteboard(name: .drag)
    private var tracker: DragSessionTracker
    private var timer: Timer?
    private var panel: NSPanel?
    private var wheel: RadialMenuView?
    private var currentURLs: [URL] = []
    private var mode = false
    private var latch = TriggerLatch()
    private var releaseGeneration = 0

    init() { tracker = DragSessionTracker(pasteboardCount: NSPasteboard(name: .drag).changeCount) }
    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 45, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        self.timer = timer
    }
    func hide() {
        panel?.orderOut(nil); panel = nil; wheel = nil
    }
    /// Keeps an open wheel in sync while the opacity slider is being dragged.
    func applyOpacity() { panel?.alphaValue = preferences.menuOpacity }
    private func poll() {
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let changed = pasteboard.changeCount
        // Loading URLs is cheap for local file drags; never inspect general clipboard contents.
        let incoming = down ? RadialMenuView.fileURLs(from: pasteboard) : []
        let armed = tracker.update(buttonDown: down, pasteboardCount: changed, hasFiles: !incoming.isEmpty)
        if !down {
            if panel != nil {
                let generation = releaseGeneration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self, self.releaseGeneration == generation else { return }
                    self.hide()
                }
            }
            currentURLs = []; latch = TriggerLatch(); return
        }
        releaseGeneration += 1
        // Tracked before the guard, so the edge is also followed while not yet
        // armed — otherwise keys held before the drag would never produce one.
        let pressed = ModifierCombo(NSEvent.modifierFlags)
        let opens = preferences.openCombo.isSatisfied(by: pressed)
        let freshPress = latch.update(armed: armed, satisfied: opens)
        guard !isBusy(), armed else {
            if isBusy() { hide() }; return
        }
        if !incoming.isEmpty { currentURLs = incoming }
        let tools = opens && preferences.toolsExtra.isSatisfied(by: pressed)
        if panel == nil {
            // Only on a fresh press: holding the keys would glue the wheel to
            // the pointer, and dismissing it must not disable the trigger.
            guard freshPress else { return }
            show(urls: currentURLs, tools: tools)
        } else if tools != mode && opens {
            let options = ActionCatalog.actions(for: currentURLs, tools: tools)
            if !options.isEmpty { mode = tools; wheel?.actions = options }
        }
    }
    private func show(urls: [URL], tools: Bool) {
        let actions = ActionCatalog.actions(for: urls, tools: tools)
        guard !actions.isEmpty else {
            // Once per press, not per tick: the latch already gates this.
            report?(tr(tools ? "status.noTools" : "status.unsupportedDrag"))
            return
        }
        mode = tools
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let frame = RadialGeometry.frame(around: pointer, size: CGSize(width: 336, height: 336), in: screen.visibleFrame)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .popUpMenu; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false; panel.acceptsMouseMovedEvents = true
        // alphaValue keeps hit testing intact, so the wheel stays a drop target.
        panel.alphaValue = preferences.menuOpacity
        let view = RadialMenuView(frame: CGRect(origin: .zero, size: frame.size))
        view.actions = actions; view.urls = urls
        view.onExit = { [weak self] in self?.hide() }
        view.onAction = { [weak self] action, files in
            guard let self else { return }; self.hide(); self.perform?(action, files)
        }
        panel.contentView = view
        self.panel = panel; wheel = view
        panel.orderFrontRegardless()
        report?(tr("status.menuOpen", urls.count))
    }
}
