import AppKit
import SwiftUI

/// Kept on the editor's window, so menu commands follow the active window.
/// Text fields receive standard editing commands first via the responder chain.
struct EditorWindowCommands {
    var canUndo: () -> Bool
    var canRedo: () -> Bool
    var undo: () -> Void
    var redo: () -> Void
    var fit: () -> Void
    var zoom: (Int) -> Void
    var save: (() -> Void)? = nil
}

struct EditorCommandBridge: NSViewRepresentable {
    var active = true
    let commands: EditorWindowCommands
    func makeNSView(context: Context) -> CommandView { CommandView() }
    func updateNSView(_ view: CommandView, context: Context) { view.commands = commands; view.active = active; view.install() }
    static func dismantleNSView(_ view: CommandView, coordinator: ()) { view.uninstall() }

    final class CommandView: NSView {
        var commands: EditorWindowCommands?
        var active = true
        weak var installedWindow: ReferenceWindow?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); install() }
        func install() {
            if installedWindow !== window || !active { uninstall() }
            guard active else { return }
            installedWindow = window as? ReferenceWindow
            installedWindow?.editorCommands = commands
            installedWindow?.editorCommandOwner = self
        }
        func uninstall() {
            if installedWindow?.editorCommandOwner === self {
                installedWindow?.editorCommands = nil; installedWindow?.editorCommandOwner = nil
            }
            installedWindow = nil
        }
    }
}

struct EditorCloseBridge: NSViewRepresentable {
    let shouldClose: () -> Bool
    func makeNSView(context: Context) -> CloseView { CloseView() }
    func updateNSView(_ view: CloseView, context: Context) { view.callback = shouldClose; view.install() }
    static func dismantleNSView(_ view: CloseView, coordinator: ()) { view.attachedWindow?.editorCloseRequest = nil }
    final class CloseView: NSView {
        var callback: (() -> Bool)?
        weak var attachedWindow: ReferenceWindow?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); install() }
        func install() { attachedWindow = window as? ReferenceWindow; attachedWindow?.editorCloseRequest = callback }
    }
}

@MainActor final class WindowDimensions: ObservableObject {
    @Published var size: CGSize
    init(_ size: CGSize) { self.size = size }
}

/// A resizable root still has an explicit frame, updated from its own window.
struct WindowSizedRoot<Content: View>: View {
    @ObservedObject var dimensions: WindowDimensions
    let content: Content
    var body: some View { content.frame(width: dimensions.size.width, height: dimensions.size.height) }
}
