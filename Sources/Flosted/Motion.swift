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

    /// Durations for the AppKit and Core Animation side, by role rather than
    /// by number, so a panel and a SwiftUI view fade with the same timing.
    enum Duration {
        /// Something leaving because the user is done with it; never in the way.
        static let short = 0.11
        /// What every fade shortens to under Reduce Motion.
        static let reduced = 0.12
        /// Swapping one content for another in place.
        static let fade = 0.18
        /// A panel or surface arriving.
        static let present = 0.2
    }
    /// Arrivals decelerate, departures accelerate, swaps do both.
    static let easeOut = CAMediaTimingFunction(name: .easeOut)
    static let easeIn = CAMediaTimingFunction(name: .easeIn)
    static let easeInOut = CAMediaTimingFunction(name: .easeInEaseOut)

    /// AppKit side of the same setting; SwiftUI views read the environment instead.
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// `withAnimation` that honours Reduce Motion, for state changed in code
    /// rather than bound to a view: the change still shows, nothing travels.
    static func animate<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
        try withAnimation(reduced ? .easeOut(duration: Duration.reduced) : animation, body)
    }

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
