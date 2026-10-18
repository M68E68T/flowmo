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
}

struct EditorCommandBridge: NSViewRepresentable {
    let commands: EditorWindowCommands
    func makeNSView(context: Context) -> CommandView { CommandView() }
    func updateNSView(_ view: CommandView, context: Context) { view.commands = commands; view.install() }
    static func dismantleNSView(_ view: CommandView, coordinator: ()) { view.installedWindow?.editorCommands = nil }

    final class CommandView: NSView {
        var commands: EditorWindowCommands?
        weak var installedWindow: ReferenceWindow?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); install() }
        func install() {
            if installedWindow !== window { installedWindow?.editorCommands = nil }
            installedWindow = window as? ReferenceWindow
            installedWindow?.editorCommands = commands
        }
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
