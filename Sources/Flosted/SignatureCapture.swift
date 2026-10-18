import AppKit
import SwiftUI
import FlostedCore

/// Freehand drawing area for mouse and trackpad.
final class SignatureDrawingView: NSView {
    private var strokes: [[CGPoint]] = []
    private var current: [CGPoint] = []
    var changed: ((Bool) -> Void)?
    override var isFlipped: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func mouseDown(with event: NSEvent) { current = [convert(event.locationInWindow, from: nil)] }
    override func mouseDragged(with event: NSEvent) {
        current.append(convert(event.locationInWindow, from: nil)); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if current.count > 1 { strokes.append(current) }
        current = []; needsDisplay = true; changed?(!strokes.isEmpty)
    }
    func clear() { strokes = []; current = []; needsDisplay = true; changed?(false) }

    private func path(scale: CGFloat = 1) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = 2.6 * scale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        for stroke in strokes + (current.count > 1 ? [current] : []) {
            guard let first = stroke.first else { continue }
            path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
            // Midpoint smoothing, otherwise fast strokes look like polygons.
            for index in 1..<stroke.count {
                let previous = stroke[index - 1], point = stroke[index]
                let mid = CGPoint(x: (previous.x + point.x) / 2 * scale, y: (previous.y + point.y) / 2 * scale)
                path.curve(to: mid, controlPoint1: CGPoint(x: previous.x * scale, y: previous.y * scale),
                           controlPoint2: CGPoint(x: previous.x * scale, y: previous.y * scale))
            }
        }
        return path
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.65).setFill(); bounds.fill()
        NSColor.black.setStroke(); path().stroke()
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        let baseline = NSBezierPath()
        baseline.move(to: CGPoint(x: 24, y: bounds.height * 0.3))
        baseline.line(to: CGPoint(x: bounds.width - 24, y: bounds.height * 0.3))
        baseline.setLineDash([4, 4], count: 2, phase: 0); baseline.stroke()
    }
    /// Transparent image at 3x, so the signature stays sharp when enlarged.
    func image() -> CGImage? {
        guard !strokes.isEmpty else { return nil }
        let scale: CGFloat = 3
        guard let context = try? ImageTools.canvas(Int(bounds.width * scale), Int(bounds.height * scale)) else { return nil }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
        NSColor.black.setStroke(); path(scale: scale).stroke()
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}

struct SignaturePad: NSViewRepresentable {
    let hasContent: (Bool) -> Void
    let register: (SignatureDrawingView) -> Void
    func makeNSView(context: Context) -> SignatureDrawingView {
        let view = SignatureDrawingView(frame: .zero)
        view.changed = hasContent
        register(view)
        return view
    }
    func updateNSView(_ view: SignatureDrawingView, context: Context) { view.changed = hasContent }
}

struct SignatureCapture: View {
    let store: SignatureStore
    let accent: Color
    let chosen: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pad: SignatureDrawingView?
    @State private var hasDrawing = false
    @State private var imported: CGImage?
    @State private var threshold = 0.72
    @State private var cleaned: CGImage?
    @State private var stored: [String: CGImage] = [:]
    @State private var errorMessage: String?

    var body: some View {
        ReferenceSurface {
            VStack(alignment: .leading, spacing: 0) {
                ReferenceHeader(title: tr("signature.title"), close: { dismiss() })
                VStack(alignment: .leading, spacing: 12) {
                    Text("signature.drawHint").font(.system(size: 10)).foregroundStyle(.secondary)
                    ZStack {
                        if let cleaned {
                            Image(nsImage: NSImage(cgImage: cleaned, size: .zero)).resizable().scaledToFit()
                        } else {
                            SignaturePad(hasContent: { hasDrawing = $0 }, register: { pad = $0 })
                        }
                    }
                    .frame(height: 150)
                    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.12), lineWidth: 0.7))

                    if imported != nil {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("signature.threshold").font(.system(size: 10)).fixedSize()
                                Spacer(minLength: 8)
                                Text("\(Int(threshold * 100)) %").font(.system(size: 10)).monospacedDigit().fixedSize()
                            }
                            Slider(value: $threshold, in: 0.3...0.95).controlSize(.mini).tint(accent)
                                .onChange(of: threshold) { _ in refreshImported() }
                        }.help(Text("help.signatureThreshold"))
                    }
                    HStack(spacing: 8) {
                        Button("signature.clear") { clear() }.buttonStyle(ReferenceActionButton())
                        Button("signature.import") { importPhoto() }.buttonStyle(ReferenceActionButton())
                            .help(Text("help.signatureImport"))
                        Spacer()
                        Button("signature.use") { useCurrent() }
                            .buttonStyle(ReferenceActionButton(primary: true))
                            .disabled(!hasDrawing && cleaned == nil)
                    }
                    if !stored.isEmpty {
                        Text("signature.saved").font(.system(size: 10, weight: .medium))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stored.keys.sorted(), id: \.self) { id in
                                    if let image = stored[id] {
                                        Button { chosen(id); dismiss() } label: {
                                            Image(nsImage: NSImage(cgImage: image, size: .zero)).resizable().scaledToFit()
                                                .frame(width: 92, height: 42)
                                                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu { Button("signature.delete", role: .destructive) { store.remove(id: id); stored = store.load() } }
                                        .help(Text("help.signatureReuse"))
                                    }
                                }
                            }
                        }.frame(height: 48)
                    }
                }.padding(.horizontal, 18).padding(.top, 14)
                Spacer(minLength: 10)
            }
        }
        .frame(width: 420, height: 470)
        .onAppear { stored = store.load() }
        .alert(Text("editor.saveFailed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func clear() {
        pad?.clear(); hasDrawing = false; imported = nil; cleaned = nil
    }
    private func importPhoto() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            imported = try ImageConverter.decode(url)
            refreshImported()
        } catch { errorMessage = error.localizedDescription }
    }
    private func refreshImported() {
        guard let imported else { return }
        cleaned = try? SignatureStore.removingWhiteBackground(imported, threshold: threshold)
    }
    private func useCurrent() {
        guard let image = cleaned ?? pad?.image() else { return }
        do {
            let id = try store.save(image)
            stored = store.load()
            chosen(id)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
