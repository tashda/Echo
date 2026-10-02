import SwiftUI

/// Echo's animations in one place (Design/04-motion.md). Views read it from the environment,
/// so the speed setting and Reduce Motion apply everywhere without each view checking them:
///
///     @Environment(\.echoMotion) private var motion
///     withAnimation(motion.standard) { isTreeVisible.toggle() }
public struct EchoMotion: Sendable, Equatable {
    /// Multiplier applied to every animation duration (the speed setting).
    public var durationScale: Double = 1
    public var reduceMotion = false

    public init(durationScale: Double = 1, reduceMotion: Bool = false) {
        self.durationScale = durationScale
        self.reduceMotion = reduceMotion
    }

    private var scale: Double { durationScale }

    /// With Reduce Motion on, movement becomes a short fade with no bounce.
    private var reduced: Animation { .easeInOut(duration: 0.18) }

    /// The house spring for anything that moves: selection, cards, panels.
    public var standard: Animation {
        reduceMotion ? reduced : .bouncy(duration: 0.45 * scale, extraBounce: 0.08)
    }

    /// Switching tabs (round 49, MO9): the plate and every tab's width on a smooth curve with no
    /// bounce. Quicker than `settle`, since it happens on every click.
    public var glide: Animation {
        reduceMotion ? reduced : .smooth(duration: 0.3 * scale)
    }

    /// A tool tab's pages fading in and out with their tab (round 49).
    public var pageFade: Animation {
        .easeOut(duration: (reduceMotion ? 0.1 : 0.18) * scale)
    }

    /// Moving something to a resting place it must not pass, such as panes growing toward the
    /// rail: the same pace as the house spring, with no overshoot.
    public var settle: Animation {
        reduceMotion ? reduced : .smooth(duration: settleDuration)
    }

    /// How long `settle` takes, for work that has to wait until it's done.
    public var settleDuration: Double { reduceMotion ? 0.18 : 0.45 * scale }

    /// Hover feedback: fills and highlights easing in.
    public var hover: Animation {
        .easeOut(duration: (reduceMotion ? 0.1 : 0.12) * scale)
    }

    /// Press and selection feedback.
    public var press: Animation {
        .easeOut(duration: (reduceMotion ? 0.1 : 0.16) * scale)
    }

    /// Folders opening and closing in the Explorer: rows slide and fade, like the native outline.
    public var expand: Animation {
        reduceMotion ? reduced : .easeInOut(duration: 0.22 * scale)
    }

    /// Scrolling the Explorer to a server or object picked elsewhere.
    public var reveal: Animation {
        reduceMotion ? reduced : .smooth(duration: 0.4 * scale)
    }

    /// Liquid stretch, leading edge: races to the target.
    public var liquidLead: Animation {
        reduceMotion ? reduced : .spring(duration: 0.28 * scale, bounce: 0.25)
    }

    /// Liquid stretch, trailing edge: follows a moment later, so the shape stretches and settles.
    public var liquidTrail: Animation {
        reduceMotion ? reduced : .spring(duration: 0.55 * scale, bounce: 0.3).delay(0.06 * scale)
    }

    /// Whether looping "in progress" effects (the connecting pulse, shimmer) should run.
    public var allowsLoopingEffects: Bool { !reduceMotion }

    /// Half a cycle of the connecting pulse (dim, then back).
    public var pulseHalfPeriod: Double { 0.7 * scale }

    /// Deepest point of the connecting pulse.
    public static let pulseMinimumOpacity: Double = 0.15
    public static let pulseMinimumScale: CGFloat = 0.9
}

extension EnvironmentValues {
    @Entry public var echoMotion = EchoMotion()
}
