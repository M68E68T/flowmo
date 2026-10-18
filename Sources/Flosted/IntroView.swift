import SwiftUI
import FlostedCore

enum IntroLayout { static let size = CGSize(width: 520, height: 580) }

struct IntroView: View {
    @ObservedObject var controller: AppController
    let close: () -> Void
    @State private var card = 0
    private let accent = ReferenceStyle.accent
    private let cardCount = 4

    /// FileKind.detect only reads the path extension and never touches disk,
    /// so a made-up path is enough to show the real wheel with real formats.
    private let sampleImage = URL(fileURLWithPath: "/beispiel.png")

    private var openKeys: String { controller.preferences.openCombo.symbols }
    private var toolKeys: String {
        let combined = controller.preferences.openCombo.union(controller.preferences.toolsExtra)
        return combined.symbols
    }

    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                ReferenceHeader(title: tr("intro.title"), close: finish)
                ZStack {
                    switch card {
                    case 0: welcome
                    case 1: convertCard
                    case 2: editCard
                    default: readyCard
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 26).padding(.top, 18)
                dots
                footer
            }
        }
        .frame(width: IntroLayout.size.width, height: IntroLayout.size.height)
    }

    private func heading(_ key: String, _ symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(accent)
            Text(LocalizedStringKey(key)).font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
        }
    }
    private func body(_ key: String) -> some View {
        Text(LocalizedStringKey(key)).font(.system(size: 12)).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
    }
    /// Non-interactive: the wheel is here to be recognised later, not used now.
    private func wheel(tools: Bool) -> some View {
        EmbeddedWheel(urls: [sampleImage], tools: tools, action: { _, _ in }, receive: { _ in })
            .frame(width: 250, height: 250).allowsHitTesting(false)
    }
    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(verbatim: "\(number)")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .frame(width: 17, height: 17).background(accent, in: Circle())
            Text(LocalizedStringKey(text)).font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Image(nsImage: BrandMark.image(side: 56, style: .mark))
                    .accessibilityHidden(true)
                Text("intro.welcome.title").font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            body("intro.welcome.body")
            VStack(alignment: .leading, spacing: 9) {
                step(1, "intro.welcome.point1")
                step(2, "intro.welcome.point2")
                step(3, "intro.welcome.point3")
            }.padding(.horizontal, 10).padding(.top, 4)
            Spacer(minLength: 0)
        }
    }
    private var convertCard: some View {
        VStack(spacing: 12) {
            heading("intro.convert.title", "arrow.triangle.2.circlepath")
            Text(tr("intro.convert.body", openKeys)).font(.system(size: 12))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            wheel(tools: false)
            Text("intro.convert.hint").font(.system(size: 10.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var editCard: some View {
        VStack(spacing: 12) {
            heading("intro.edit.title", "signature")
            Text(tr("intro.edit.body", toolKeys)).font(.system(size: 12))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            wheel(tools: true)
            Text("intro.edit.hint").font(.system(size: 10.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var readyCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            heading("intro.ready.title", "checkmark.circle")
            body("intro.ready.body")
            VStack(alignment: .leading, spacing: 9) {
                step(1, "intro.ready.point1")
                step(2, "intro.ready.point2")
                step(3, "intro.ready.point3")
            }.padding(.horizontal, 10)
            Button("intro.loadSample") { controller.loadExample(); finish() }
                .buttonStyle(ReferenceActionButton(primary: true))
                .help(Text("help.trySample")).padding(.top, 6)
            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<cardCount, id: \.self) { index in
                Circle().fill(index == card ? accent : .black.opacity(0.15))
                    .frame(width: 6, height: 6)
            }
        }.padding(.vertical, 12)
    }
    private var footer: some View {
        HStack {
            Button("intro.back") { card = max(0, card - 1) }
                .buttonStyle(ReferenceActionButton()).disabled(card == 0)
            Spacer()
            Button(tr(card == cardCount - 1 ? "intro.finish" : "intro.next")) {
                if card == cardCount - 1 { finish() } else { card += 1 }
            }
            .buttonStyle(ReferenceActionButton(primary: true)).keyboardShortcut(.defaultAction)
        }
        .padding(13)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.075)).frame(height: 0.6) }
    }
    /// Any way out counts as seen, so it never reappears on its own.
    private func finish() {
        IntroState.markSeen()
        close()
    }
}
