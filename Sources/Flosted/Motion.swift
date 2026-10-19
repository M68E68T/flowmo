import AppKit
import SwiftUI

/// One set of motion tokens for the whole app, so every surface moves with the
/// same character: quick to respond, settled without overshoot, never in the way.
/// Animations never gate input; an action starts on the click, not after it.
enum Motion {
    /// Selection, toggles and indicators that follow the pointer.
    static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.86)
    /// Content and state changes: views appearing, cards, inserted rows.
    static let smooth = Animation.spring(response: 0.40, dampingFraction: 0.90)
    /// Hover, colour and text changes.
    static let quick = Animation.easeOut(duration: 0.12)
    /// Default for anything that appears or disappears in place.
    static let appear = AnyTransition.opacity.combined(with: .scale(scale: 0.96))

    /// AppKit side of the same setting; SwiftUI views read the environment instead.
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Same character as `snappy`, for Core Animation.
    static func spring(_ keyPath: String) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1
        animation.stiffness = 420
        animation.damping = 36
        animation.initialVelocity = 0
        animation.duration = min(animation.settlingDuration, 0.45)
        return animation
    }
}

extension View {
    /// `animation(_:value:)` that falls back to a plain fade when the user
    /// asked for reduced motion: state still changes visibly, nothing travels.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeOut(duration: 0.12) : animation, value: value)
    }
}
