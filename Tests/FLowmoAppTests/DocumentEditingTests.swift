import XCTest
import AppKit
import FLowmoCore
@testable import FLowmo

final class DocumentEditingTests: XCTestCase {
    @MainActor private func setup(_ value: String = "Alpha Beta") throws -> (DocumentEditorModel, DocumentPagesScrollView, DocumentTextView) {
        let model = DocumentEditorModel()
        try model.install(DocumentSnapshot(NSAttributedString(string: value, attributes: DocumentImporter.defaultAttributes)))
        let scroll = DocumentPagesScrollView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        scroll.model = model; scroll.synchronize()
        let view = try XCTUnwrap(scroll.textViews.first)
        model.activeTextView = view
        return (model, scroll, view)
    }
    @MainActor private func key(_ character: String, flags: NSEvent.ModifierFlags = .command) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil, characters: character,
            charactersIgnoringModifiers: character, isARepeat: false, keyCode: 0))
    }

    @MainActor func testDirectTypingGroupsUndoAndPreservesUnicode() async throws {
        let (model, scroll, view) = try setup()
        view.setSelectedRange(NSRange(location: 6, length: 4))
        view.insertText("Türkçe ÄÖÜ", replacementRange: view.selectedRange())
        view.insertText("!", replacementRange: view.selectedRange())
        XCTAssertEqual(model.layout?.storage.string, "Alpha Türkçe ÄÖÜ!")
        XCTAssertTrue(model.dirty)
        model.undo()
        XCTAssertEqual(model.layout?.storage.string, "Alpha Beta")
        XCTAssertFalse(model.dirty)
        model.redo()
        XCTAssertEqual(model.layout?.storage.string, "Alpha Türkçe ÄÖÜ!")
        withExtendedLifetime(scroll) {}
    }

    @MainActor func testSelectionFormattingAndKeyboardUndoAreIndependentOfAnnotations() async throws {
        let (model, scroll, view) = try setup()
        view.setSelectedRange(NSRange(location: 0, length: 5))
        XCTAssertTrue(view.performKeyEquivalent(with: try key("b")))
        model.setFontSize(24)
        model.toggleUnderline(); model.setAlignment(.center)
        let storage = try XCTUnwrap(model.layout?.storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        XCTAssertTrue(NSFontManager.shared.traits(of: try XCTUnwrap(attrs[.font] as? NSFont)).contains(.boldFontMask))
        XCTAssertEqual((attrs[.font] as? NSFont)?.pointSize, 24)
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual((attrs[.paragraphStyle] as? NSParagraphStyle)?.alignment, .center)
        XCTAssertEqual((storage.attribute(.font, at: 7, effectiveRange: nil) as? NSFont)?.pointSize, 12)
        XCTAssertTrue(view.performKeyEquivalent(with: try key("z")))
        XCTAssertNotEqual((storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .center)
        XCTAssertTrue(view.performKeyEquivalent(with: try key("z", flags: [.command, .shift])))
        XCTAssertEqual((storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .center)
        withExtendedLifetime(scroll) {}
    }

    @MainActor func testCaretFormattingAffectsNewTextWithoutChangingExistingText() async throws {
        let (model, scroll, view) = try setup("Vorher ")
        view.setSelectedRange(NSRange(location: 7, length: 0))
        model.toggleBold(); model.setFontSize(22)
        XCTAssertFalse(model.dirty)
        view.insertText("Nachher", replacementRange: view.selectedRange())
        let storage = try XCTUnwrap(model.layout?.storage)
        XCTAssertEqual((storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 12)
        XCTAssertEqual((storage.attribute(.font, at: 8, effectiveRange: nil) as? NSFont)?.pointSize, 22)
        model.undo(); XCTAssertEqual(storage.string, "Vorher ")
        withExtendedLifetime(scroll) {}
    }

    @MainActor func testListsContinueAndEmptyItemEndsTheList() async throws {
        let (model, scroll, view) = try setup("Alpha")
        view.setSelectedRange(NSRange(location: 5, length: 0))
        model.setList(.numbered)
        XCTAssertEqual(view.string, "1.\tAlpha")
        view.insertNewline(nil)
        view.insertText("Beta", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "1.\tAlpha\n2.\tBeta")
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "1.\tAlpha\n2.\tBeta\n3.\t")
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "1.\tAlpha\n2.\tBeta\n")
        view.insertText("Ohne Liste", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "1.\tAlpha\n2.\tBeta\nOhne Liste")
        XCTAssertTrue((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.isEmpty ?? true)
        withExtendedLifetime(scroll) {}
    }

    @MainActor func testPaginationGrowsShrinksAndZoomStaysStable() async throws {
        let (model, scroll, view) = try setup("Start")
        let initialScale = scroll.magnification
        for _ in 0..<10 { scroll.synchronize() }
        XCTAssertEqual(scroll.magnification, initialScale, accuracy: 0.001)
        view.setSelectedRange(NSRange(location: 0, length: view.string.utf16.count))
        view.insertText(String(repeating: "Eine Zeile\n", count: 120), replacementRange: view.selectedRange())
        scroll.synchronize()
        XCTAssertGreaterThan(scroll.textViews.count, 1)
        XCTAssertEqual(scroll.textViews.count, model.layout?.containers.count)
        view.setSelectedRange(NSRange(location: 0, length: view.string.utf16.count))
        view.insertText("Kurz\n", replacementRange: view.selectedRange())
        scroll.synchronize()
        XCTAssertEqual(scroll.textViews.count, 1)
        XCTAssertNotNil(model.layout?.manager.extraLineFragmentTextContainer)
        model.stepZoom(1); scroll.synchronize()
        XCTAssertGreaterThan(scroll.magnification, initialScale)
        XCTAssertFalse(view.mouseDownCanMoveWindow)
    }

    @MainActor func testInactiveCommandBridgeCannotClearTheActiveMode() async throws {
        let window = ReferenceWindow(size: CGSize(width: 720, height: 560), title: "Test")
        window.isReleasedWhenClosed = false
        let root = NSView(); window.contentView = root
        let first = EditorCommandBridge.CommandView(), second = EditorCommandBridge.CommandView()
        var undos = 0
        let commands = EditorWindowCommands(canUndo: { true }, canRedo: { false }, undo: { undos += 1 }, redo: {}, fit: {}, zoom: { _ in })
        first.commands = commands; second.commands = commands
        root.addSubview(first); root.addSubview(second)
        second.install(); first.active = false; first.install()
        XCTAssertTrue(window.editorCommandOwner === second)
        window.undo(nil); XCTAssertEqual(undos, 1)
        var closes = 0
        window.editorCloseRequest = { closes += 1; return false }
        window.performClose(nil)
        XCTAssertEqual(closes, 1)
        window.editorCloseRequest = nil; window.close()
    }

    @MainActor func testWindowRoutesTextCommandsAndSaveWhileTextViewHasFocus() async throws {
        let (model, scroll, view) = try setup()
        let window = ReferenceWindow(size: CGSize(width: 900, height: 600), title: "Test")
        window.isReleasedWhenClosed = false; window.contentView = scroll
        XCTAssertTrue(window.makeFirstResponder(view))
        view.setSelectedRange(NSRange(location: 0, length: 5))
        XCTAssertTrue(window.performKeyEquivalent(with: try key("b")))
        XCTAssertTrue(model.bold)
        XCTAssertTrue(window.performKeyEquivalent(with: try key("z")))
        XCTAssertFalse(model.bold)
        XCTAssertTrue(window.performKeyEquivalent(with: try key("z", flags: [.command, .shift])))
        XCTAssertTrue(model.bold)
        var saves = 0
        window.editorCommands = EditorWindowCommands(canUndo: { true }, canRedo: { false }, undo: {}, redo: {}, fit: {}, zoom: { _ in }, save: { saves += 1 })
        XCTAssertTrue(window.performKeyEquivalent(with: try key("s")))
        XCTAssertEqual(saves, 1)
        window.close()
    }
}
