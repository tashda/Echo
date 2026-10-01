import SwiftUI

/// Where the welcome's mark is in its life.
nonisolated enum WelcomeMarkPhase: Equatable {
    case hidden
    case playing(Date)
    case resting
    case leaving(Date)
}

/// The motion of the welcome and the departure when a server connects (round 48). The mark's
/// echo is echodb.dev's `Mark.astro`: each pill slides in from 110 units to the left (of the
/// mark's 568) and fades in on cubic-bezier(0.3, 1.3, 0.5, 1), 0.9 s long, 0.12 s apart. All
/// times are seconds at normal speed; multiply by `EchoMotion.durationScale`.
nonisolated enum WelcomeMarkMotion {
    static let viewWidth: CGFloat = 568
    static let viewHeight: CGFloat = 388
    static let travel: CGFloat = 110

    static let pillDuration = 0.9
    static let pillStagger = 0.12
    /// The mark starts a moment after the welcome appears.
    static let startDelay = 0.25
    static let leaveDuration = 0.34
    static let leaveStagger = 0.06
    static var leaveTotal: Double { leaveDuration + leaveStagger * 2 }

    /// The buttons, then the recents, rise in after the mark has begun.
    static let restDelay = 0.55
    static let restGap = 0.15
    static let riseDuration = 0.45
    static let riseDistance: CGFloat = 10

    /// Connecting: the pills leave first, then the server grows into the rail, then the tree
    /// slides out from behind it.
    static var railDelay: Double { leaveTotal + 0.06 }
    static let treeLag = 0.12

    /// The server page builds up (round 48, AR2): four pieces 0.06 s apart.
    static let pageStartDelay = 0.15
    static let pieceGap = 0.06
    static let pieceDuration = 0.35
    static let pieceDistance: CGFloat = 8
    static let pieceCount = 4

    /// Closing the last tab lifts the card away from the page that is already underneath.
    static let revealDuration = 0.28
    static let revealScale: CGFloat = 0.985

    /// One pill's horizontal offset, in the artwork's units, and its opacity.
    static func pillFrame(phase: WelcomeMarkPhase, index: Int, at now: Date, scale: Double) -> (offset: CGFloat, opacity: Double) {
        switch phase {
        case .hidden:
            return (-travel, 0)
        case .resting:
            return (0, 1)
        case .playing(let start):
            let local = (now.timeIntervalSince(start) / scale - Double(index) * pillStagger) / pillDuration
            let eased = bezier(clamp(local), 0.3, 1.3, 0.5, 1)
            return (-travel * (1 - eased), clamp(eased))
        case .leaving(let start):
            // Last pill first, quicker than coming in.
            let local = (now.timeIntervalSince(start) / scale - Double(2 - index) * leaveStagger) / leaveDuration
            let eased = bezier(clamp(local), 0.5, 0, 0.9, 0.6)
            return (-travel * eased, 1 - eased)
        }
    }

    /// How long a moving phase lasts, so the clock can stop.
    static func length(of phase: WelcomeMarkPhase, scale: Double) -> Double? {
        switch phase {
        case .playing: (pillDuration + pillStagger * 2 + 0.1) * scale
        case .leaving: (leaveTotal + 0.1) * scale
        case .hidden, .resting: nil
        }
    }

    /// CSS's `cubic-bezier(x1, y1, x2, y2)`: the curve's value at progress `x`.
    static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        guard x > 0, x < 1 else { return x <= 0 ? 0 : 1 }
        func axis(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low = 0.0
        var high = 1.0
        var t = x
        for _ in 0..<24 {
            t = (low + high) / 2
            if axis(t, x1, x2) < x { low = t } else { high = t }
        }
        return axis(t, y1, y2)
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
