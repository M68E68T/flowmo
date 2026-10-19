import SwiftUI
import FlostedCore

enum IntroLayout { static let size = CGSize(width: 520, height: 580) }

struct IntroView: View {
    @ObservedObject var controller: AppController
    let close: () -> Void
    @State private var card = 0
    /// Which way the last step went, so cards slide in from the side they came from.
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accent = ReferenceStyle.accent
    private let cardCount = 4

    private var openKeys: String { controller.preferences.openCombo.symbols }
    private var toolKeys: String {
        let combined = controller.preferences.openCombo.union(controller.preferences.toolsExtra)
        return combined.symbols
    }

    var body: some View {
        ReferenceSurface {
            VStack(spacing: 0) {
                ReferenceHeader(title: tr("intro.title"), close: finish)
                // The outer stack holds both cards while they pass each other;
                // directly in the VStack they would sit one above the other.
                ZStack {
                    ZStack {
                        switch card {
                        case 0: welcome
                        case 1: convertCard
                        case 2: editCard
                        default: tryCard
                        }
                    }
                    .id(card)
                    .transition(cardTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 26).padding(.top, 18)
                .clipped()
                dots
                footer
            }
        }
        .frame(width: IntroLayout.size.width, height: IntroLayout.size.height)
    }

    private var cardTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let shift: CGFloat = 24
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: forward ? shift : -shift)),
            removal: .opacity.combined(with: .offset(x: forward ? -shift : shift)))
    }
    private func go(to next: Int) {
        forward = next > card
        Motion.animate(Motion.smooth) { card = next }
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
        WheelIllustration(tools: tools).frame(width: 250, height: 250)
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
    /// For lists that are not a sequence; numbers would read as steps to follow.
    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(accent)
                .frame(width: 17, height: 17).accessibilityHidden(true)
            Text(LocalizedStringKey(text)).font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // The window header already welcomes, so this card opens with the mark alone.
    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(nsImage: BrandMark.image(side: 56, style: .mark))
                .accessibilityHidden(true)
            body("intro.welcome.body")
            VStack(alignment: .leading, spacing: 9) {
                point("arrow.triangle.2.circlepath", "intro.welcome.point1")
                point("crop", "intro.welcome.point2")
                point("lock.shield", "intro.welcome.point3")
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
    /// Practises the real gesture in Finder instead of a click inside Flosted.
    private var tryCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            heading("intro.try.title", "hand.point.up.left")
            VStack(alignment: .leading, spacing: 9) {
                step(1, "intro.try.step1")
                step(2, tr("intro.try.step2", openKeys))
                step(3, "intro.try.step3")
            }.padding(.horizontal, 10)
            Button("intro.revealSample") { controller.revealExample(); finish() }
                .buttonStyle(ReferenceActionButton(primary: true))
                .help(Text("help.revealSample")).padding(.top, 2)
            point("menubar.rectangle", "intro.try.note")
                .foregroundStyle(.secondary).padding(.horizontal, 10).padding(.top, 6)
            Spacer(minLength: 0)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<cardCount, id: \.self) { index in
                Capsule().fill(index == card ? accent : .black.opacity(0.15))
                    .frame(width: index == card ? 16 : 6, height: 6)
            }
        }.padding(.vertical, 12)
        .motion(Motion.snappy, value: card)
    }
    private var footer: some View {
        HStack {
            Button("intro.back") { go(to: max(0, card - 1)) }
                .buttonStyle(ReferenceActionButton()).disabled(card == 0)
            Spacer()
            Button(tr(card == cardCount - 1 ? "intro.finish" : "intro.next")) {
                if card == cardCount - 1 { finish() } else { go(to: card + 1) }
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
