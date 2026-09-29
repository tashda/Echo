import SwiftUI

/// Echo's animations in one place (Design/04-motion.md). Views read it from the environment,
/// so the speed setting and Reduce Motion apply everywhere without each view checking them:
///
///     @Environment(\.echoMotion) private var motion
///     withAnimation(motion.standard) { isTreeVisible.toggle() }
struct EchoMotion: Sendable, Equatable {
    var speed: InterfaceMotionSpeed = .standard
    var reduceMotion = false

    private var scale: Double { speed.durationScale }

    /// With Reduce Motion on, movement becomes a short fade with no bounce.
    private var reduced: Animation { .easeInOut(duration: 0.18) }

    /// The house spring for anything that moves: selection, cards, panels.
    var standard: Animation {
        reduceMotion ? reduced : .bouncy(duration: 0.45 * scale, extraBounce: 0.08)
    }

    /// Moving something to a resting place it must not pass, such as panes growing toward the
    /// rail: the same pace as the house spring, with no overshoot.
    var settle: Animation {
        reduceMotion ? reduced : .smooth(duration: settleDuration)
    }

    /// How long `settle` takes, for work that has to wait until it's done.
    var settleDuration: Double { reduceMotion ? 0.18 : 0.45 * scale }

    /// Hover feedback: fills and highlights easing in.
    var hover: Animation {
        .easeOut(duration: (reduceMotion ? 0.1 : 0.12) * scale)
    }

    /// Press and selection feedback.
    var press: Animation {
        .easeOut(duration: (reduceMotion ? 0.1 : 0.16) * scale)
    }

    /// Folders opening and closing in the Explorer: rows slide and fade, like the native outline.
    var expand: Animation {
        reduceMotion ? reduced : .easeInOut(duration: 0.22 * scale)
    }

    /// Scrolling the Explorer to a server or object picked elsewhere.
    var reveal: Animation {
        reduceMotion ? reduced : .smooth(duration: 0.4 * scale)
    }

    /// Liquid stretch, leading edge: races to the target.
    var liquidLead: Animation {
        reduceMotion ? reduced : .spring(duration: 0.28 * scale, bounce: 0.25)
    }

    /// Liquid stretch, trailing edge: follows a moment later, so the shape stretches and settles.
    var liquidTrail: Animation {
        reduceMotion ? reduced : .spring(duration: 0.55 * scale, bounce: 0.3).delay(0.06 * scale)
    }

    /// Whether looping "in progress" effects (the connecting pulse, shimmer) should run.
    var allowsLoopingEffects: Bool { !reduceMotion }

    /// Half a cycle of the connecting pulse (dim, then back).
    var pulseHalfPeriod: Double { 0.7 * scale }

    /// Deepest point of the connecting pulse.
    static let pulseMinimumOpacity: Double = 0.15
    static let pulseMinimumScale: CGFloat = 0.9
}

extension EnvironmentValues {
    @Entry var echoMotion = EchoMotion()
}

/// Publishes `EchoMotion` from the user's speed setting and the system's Reduce Motion.
/// Apply it inside the environment that carries `ProjectStore`.
struct EchoMotionProvider: ViewModifier {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(
            \.echoMotion,
            EchoMotion(speed: projectStore.globalSettings.interfaceMotionSpeed, reduceMotion: reduceMotion)
        )
    }
}

extension View {
    /// Makes `\.echoMotion` follow the user's settings for everything inside.
    func providesEchoMotion() -> some View {
        modifier(EchoMotionProvider())
    }
}
