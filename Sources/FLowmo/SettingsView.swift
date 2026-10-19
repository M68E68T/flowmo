import SwiftUI
import FLowmoCore

/// Window and view must agree on the size: assigning an NSHostingController as
/// contentViewController makes AppKit adopt the view's intrinsic size, which
/// would otherwise shrink the window and break the labels.
enum SettingsLayout { static let size = CGSize(width: 360, height: 400) }

/// Narrow vertical glass window matching the editor windows, never a dark panel.
struct SettingsView: View {
    @ObservedObject var controller: AppController
    @State private var draft: Preferences

    init(controller: AppController) {
        self.controller = controller
        _draft = State(initialValue: controller.preferences)
    }

    var body: some View {
        ReferenceSurface {
            VStack(alignment: .leading, spacing: 0) {
                ReferenceHeader(title: tr("settings.title"), close: { controller.closeSettings() })
                VStack(alignment: .leading, spacing: 16) {
                    section("settings.openCombo", combo: $draft.openCombo, hint: "settings.openComboHint")
                        .help(Text("help.settingsOpenCombo"))
                    section("settings.toolsExtra", combo: $draft.toolsExtra, hint: draft.toolsExtra.isEmpty ? "settings.toolsDisabledHint" : "settings.toolsExtraHint")
                        .help(Text("help.settingsToolsExtra"))
                    // Fixed height so the layout never jumps while toggling keys.
                    VStack(alignment: .leading, spacing: 5) {
                        if draft.openCombo.contains(.command) {
                            note("settings.commandNote").transition(.opacity)
                        }
                        if let problem = draft.problem {
                            note(problem.messageKey).foregroundStyle(ReferenceStyle.accent)
                                .transition(.opacity)
                        }
                        Spacer(minLength: 0)
                    }.frame(height: 46, alignment: .top)
                    // Notes fade inside their reserved slot, so nothing below moves.
                    .motion(Motion.quick, value: draft.openCombo.contains(.command))
                    .motion(Motion.quick, value: draft.problem?.messageKey)
                    Divider().opacity(0.4)
                    ReferenceSlider(title: "settings.menuOpacity", value: live(\.menuOpacity))
                        .help(Text("help.settingsOpacity"))
                }
                .padding(.horizontal, 18).padding(.top, 15)
                Spacer(minLength: 12)
                HStack {
                    // Reset only fills the draft; it takes effect with Apply.
                    Button("settings.reset") { draft = .default }
                        .buttonStyle(ReferenceActionButton()).help(Text("help.settingsReset"))
                    Spacer()
                    Button("settings.apply") { controller.commit(draft); controller.closeSettings() }
                        .buttonStyle(ReferenceActionButton(primary: true))
                        .disabled(draft.problem != nil).help(Text("help.settingsApply"))
                }
                .padding(13)
                .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
            }
        }.frame(width: SettingsLayout.size.width, height: SettingsLayout.size.height)
    }

    /// Writes to the draft only; nothing is stored before Apply.
    private func live(_ path: WritableKeyPath<Preferences, Double>) -> Binding<Double> {
        Binding(get: { draft[keyPath: path] },
                set: { draft[keyPath: path] = Preferences.clamp($0) })
    }

    private func section(_ title: LocalizedStringKey, combo: Binding<ModifierCombo>,
                         hint: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(combo.wrappedValue.isEmpty ? "—" : combo.wrappedValue.symbols)
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.opacity)
                    .motion(Motion.quick, value: combo.wrappedValue)
            }
            ModifierPicker(combo: combo)
            Text(hint).font(.system(size: 9.5)).foregroundStyle(.secondary)
        }
    }
    private func note(_ key: String) -> some View {
        Text(tr(key)).font(.system(size: 9.5)).fixedSize(horizontal: false, vertical: true)
    }
}
