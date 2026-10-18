import AppKit
import SwiftUI

/// AppKit supplies a real end callback for success, Escape and releases outside
/// every drop target. SwiftUI's onDrag alone cannot clean up those last cases.
struct PageDragSource: NSViewRepresentable {
    let image: NSImage?
    let label: String
    let token: String
    let selected: Bool
    let clicked: (NSEvent.ModifierFlags) -> Void
    let began: () -> Void
    let ended: (Bool) -> Void

    func makeNSView(context: Context) -> SourceView { SourceView() }
    func updateNSView(_ view: SourceView, context: Context) {
        view.image = image; view.token = token
        view.clicked = clicked; view.began = began; view.ended = ended
        view.setAccessibilityElement(true); view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(label); view.setAccessibilityHelp(tr("help.pagesReorder"))
        view.setAccessibilityValue(selected ? 1 : 0)
    }

    final class SourceView: NSView, NSDraggingSource {
        var image: NSImage?
        var token = ""
        var clicked: ((NSEvent.ModifierFlags) -> Void)?
        var began: (() -> Void)?
        var ended: ((Bool) -> Void)?
        private var start: CGPoint?
        private var dragging = false
        override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil) }
        override func mouseDragged(with event: NSEvent) {
            guard !dragging, let start else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard hypot(point.x - start.x, point.y - start.y) > 3 else { return }
            let item = NSPasteboardItem(); item.setString(token, forType: .string)
            let drag = NSDraggingItem(pasteboardWriter: item)
            drag.setDraggingFrame(bounds, contents: image ?? NSImage(size: bounds.size))
            dragging = true; began?()
            beginDraggingSession(with: [drag], event: event, source: self)
        }
        override func mouseUp(with event: NSEvent) {
            if !dragging, start != nil { clicked?(event.modifierFlags) }
            start = nil
        }
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            dragging = false; start = nil
            ended?(operation.contains(.move))
        }
        override func accessibilityPerformPress() -> Bool { clicked?([]); return true }
    }
}
