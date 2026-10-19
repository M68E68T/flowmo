import XCTest
import AppKit
import FlostedCore
@testable import Flosted

/// The hot sector is a rotated layer mask, not a repaint: prove it lands on
/// the sector the pointer is over, in AppKit's orientation, and nowhere else.
final class RadialHighlightTests: XCTestCase {
    @MainActor private func render(_ view: NSView) throws -> NSBitmapImageRep {
        view.displayIfNeeded()
        CATransaction.flush()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        rep.size = view.bounds.size
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        view.layer?.render(in: context.cgContext)
        return rep
    }

    /// Outer part of a sector, clear of its label.
    private func probe(_ index: Int, count: Int, in view: RadialMenuView) -> CGPoint {
        let angle = (90 - Double(index) * 360 / Double(count)) * .pi / 180
        let r = view.radius * 0.88
        return CGPoint(x: view.center.x + cos(angle) * r, y: view.center.y + sin(angle) * r)
    }

    /// colorAt works in pixels, top-down; the view in points, bottom-up.
    private func color(at point: CGPoint, in image: NSBitmapImageRep, height: CGFloat) -> NSColor? {
        let scale = CGFloat(image.pixelsHigh) / height
        return image.colorAt(x: Int(point.x * scale), y: Int((height - point.y) * scale))
    }

    private func isOrange(_ color: NSColor?) -> Bool {
        // Hue, not exact values: the cold sectors are near-grey (r ≈ g ≈ b).
        guard let c = color?.usingColorSpace(.genericRGB) else { return false }
        return c.redComponent > 0.7 && c.redComponent - c.greenComponent > 0.3
            && c.redComponent - c.blueComponent > 0.5
    }

    @MainActor func testHighlightCoversOnlyTheSelectedSector() throws {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 336, height: 336),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let view = RadialMenuView(frame: CGRect(x: 0, y: 0, width: 336, height: 336))
        window.contentView = view
        view.actions = ActionCatalog.actions(for: [URL(fileURLWithPath: "/x.png")], tools: false)
        let count = view.actions.count
        XCTAssertGreaterThan(count, 2)
        view.layoutSubtreeIfNeeded()

        for target in [1, count - 1, 0] {
            view.selected = target
            view.display()
            let image = try render(view)
            for index in 0..<count {
                let point = probe(index, count: count, in: view)
                let color = color(at: point, in: image, height: view.bounds.height)
                XCTAssertGreaterThan(color?.alphaComponent ?? 0, 0.3, "Rad wurde nicht gerendert")
                XCTAssertEqual(isOrange(color), index == target,
                               "Sektor \(index) bei Auswahl \(target): \(String(describing: color))")
            }
        }

        view.selected = nil
        view.display()
        let image = try render(view)
        let point = probe(0, count: count, in: view)
        XCTAssertFalse(isOrange(color(at: point, in: image, height: view.bounds.height)))
    }
}
