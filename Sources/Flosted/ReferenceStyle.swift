import AppKit
import SwiftUI
import FlostedCore

/// Looks a text up in Bundle.main. SwiftUI resolves plain string *literals*
/// on its own; this is for AppKit titles and for texts with inserted values,
/// where interpolating into the literal would corrupt the key.
/// Translations live only in Resources/*.lproj at the project root, which
/// build-app.sh copies into the bundle and LocalizationTests reads directly.
/// Build-tool output uses plain strings instead, so no second copy is needed.
func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

enum ReferenceStyle {
    static let accent = Color(nsColor: BrandMark.accent)
    /// Same colour for the AppKit canvases that draw with CoreGraphics.
    static let accentCG = BrandMark.accent.cgColor
    static let ink = Color(red: 0.13, green: 0.10, blue: 0.07)
    static let windowRadius: CGFloat = 20
}

struct ReferenceGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .aqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct ReferenceSurface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            ReferenceGlass()
            Color(red: 1, green: 0.71, blue: 0.34).opacity(0.08)
            content
        }
        .foregroundStyle(ReferenceStyle.ink)
        .preferredColorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: ReferenceStyle.windowRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ReferenceStyle.windowRadius, style: .continuous).strokeBorder(.black.opacity(0.16), lineWidth: 0.7))
    }
}

struct ReferenceHeader: View {
    let title: String
    let close: () -> Void
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                }.buttonStyle(ReferenceIconButton()).accessibilityLabel(Text("common.close"))
                Spacer()
            }.padding(.horizontal, 13)
        }.frame(height: 40)
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
    }
}

struct ReferenceSegments: View {
    let values: [(String, Double)]
    @Binding var selection: Double
    @Namespace private var indicator
    var body: some View {
        HStack(spacing: 1) {
            ForEach(values, id: \.0) { label, value in
                Button { selection = value } label: {
                    Text(label).font(.system(size: 10.5, weight: selection == value ? .medium : .regular))
                        .frame(maxWidth: .infinity).frame(height: 21)
                        .foregroundStyle(selection == value ? .white : ReferenceStyle.ink)
                        .background {
                            // One shared shape slides between segments instead of
                            // one segment switching off and another switching on.
                            if selection == value {
                                RoundedRectangle(cornerRadius: 4).fill(ReferenceStyle.accent)
                                    .matchedGeometryEffect(id: "selection", in: indicator)
                            }
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(2).background(.black.opacity(0.065), in: RoundedRectangle(cornerRadius: 6))
        .motion(Motion.snappy, value: selection)
    }
}

struct ReferenceActionButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, primary: primary)
    }
}

/// A view, not inline in the style, so it can hold hover state. Presses answer
/// at once and release with a short spring; hover only deepens the fill.
private struct ActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    private var fill: Color {
        if primary { return ReferenceStyle.accent.opacity(configuration.isPressed ? 0.75 : (hovering ? 0.9 : 1)) }
        return Color.black.opacity(configuration.isPressed ? 0.12 : (hovering ? 0.09 : 0.065))
    }
    var body: some View {
        configuration.label.font(.system(size: 11, weight: primary ? .semibold : .regular))
            .padding(.horizontal, 10).frame(height: 23)
            .foregroundStyle(primary ? Color.white : ReferenceStyle.ink)
            .background(fill, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(primary ? Color.black.opacity(0.13) : .clear, lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { hovering = $0 && isEnabled }
            .motion(Motion.quick, value: hovering)
            .motion(Motion.snappy, value: configuration.isPressed)
            .motion(Motion.quick, value: isEnabled)
    }
}

/// The small round buttons (close, settings) with the same hover and press feel.
struct ReferenceIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false
    var body: some View {
        configuration.label
            .frame(width: 22, height: 22)
            .background(.black.opacity(configuration.isPressed ? 0.13 : (hovering ? 0.09 : 0.055)), in: Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .onHover { hovering = $0 }
            .motion(Motion.quick, value: hovering)
            .motion(Motion.snappy, value: configuration.isPressed)
    }
}

final class ReferenceWindow: NSWindow {
    let dimensions: WindowDimensions
    /// The size asked for at creation. `dimensions` follows every resize,
    /// including the hosting controller's provisional one.
    let preferredSize: CGSize
    var editorCommands: EditorWindowCommands?
    private var resizeObserver: NSObjectProtocol?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    init(size: CGSize, title: String, resizable: Bool = false) {
        dimensions = WindowDimensions(size)
        preferredSize = size
        var mask: NSWindow.StyleMask = [.borderless]
        if resizable { mask.insert(.resizable) }
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        self.title = title
        isOpaque = false; backgroundColor = .clear; hasShadow = true
        isMovableByWindowBackground = true; isReleasedWhenClosed = false
        appearance = NSAppearance(named: .aqua)
        // The system's own short fade-and-scale on open and close; it follows
        // Reduce Motion by itself.
        animationBehavior = .utilityWindow
        resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
            object: self, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let size = self.contentView?.bounds.size, size != self.dimensions.size else { return }
                    self.dimensions.size = size
                }
            }
    }
    deinit { if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) } }

    @objc func undo(_ sender: Any?) { if editorCommands?.canUndo() == true { editorCommands?.undo() } }
    @objc func redo(_ sender: Any?) { if editorCommands?.canRedo() == true { editorCommands?.redo() } }
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return editorCommands?.canUndo() ?? false }
        if item.action == #selector(redo(_:)) { return editorCommands?.canRedo() ?? false }
        return super.validateUserInterfaceItem(item)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Borderless hosting windows can consume SwiftUI key equivalents
        // before the Edit menu. Route editor commands here; leave text editing
        // and attached sheets to the native responder chain.
        if attachedSheet == nil, !(firstResponder is NSTextView), let commands = editorCommands,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z", "Z":
                if event.modifierFlags.contains(.shift) {
                    if commands.canRedo() { commands.redo() }
                } else if commands.canUndo() { commands.undo() }
                return true
            case "0": commands.fit(); return true
            case "+", "=": commands.zoom(1); return true
            case "-": commands.zoom(-1); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct ReferenceSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // fixedSize: squeeze the spacer, never break the words.
                Text(title).font(.system(size: 10.5)).fixedSize()
                Spacer(minLength: 8)
                Text("\(Int(value * 100)) %").font(.system(size: 10)).foregroundStyle(.secondary)
                    .monospacedDigit().fixedSize()
            }
            Slider(value: $value, in: Preferences.opacityRange).controlSize(.mini)
                .tint(ReferenceStyle.accent)
        }
    }
}

/// Four modifier toggles in the usual macOS order.
struct ModifierPicker: View {
    @Binding var combo: ModifierCombo
    var body: some View {
        HStack(spacing: 5) {
            ForEach(ModifierCombo.ordered, id: \.symbol) { entry in
                let on = combo.contains(entry.key)
                Button {
                    if on { combo.remove(entry.key) } else { combo.insert(entry.key) }
                } label: {
                    Text(entry.symbol)
                        .font(.system(size: 14, weight: on ? .semibold : .regular))
                        .frame(maxWidth: .infinity).frame(height: 30)
                        .foregroundStyle(on ? .white : ReferenceStyle.ink)
                        .background(on ? ReferenceStyle.accent : .black.opacity(0.065),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(Text(LocalizedStringKey(entry.name)))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .motion(Motion.snappy, value: combo)
    }
}

/// Plain look, but the key gives a little under the finger.
private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .motion(Motion.snappy, value: configuration.isPressed)
    }
}
