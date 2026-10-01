import SwiftUI

/// The dock switch's timing (round 19, S3), scaled by the speed setting: the veil fades in, the
/// section swaps under it while the card's edge moves, then the veil fades out.
public struct ExplorerDockSwitchTiming: Sendable {
    public let fadeOutDuration: Double
    public let fadeInDuration: Double
    public let fadeOut: Animation
    public let fadeIn: Animation
    /// Fade out, the edge moving, fade in: how long the window is held still.
    public let totalDuration: Double

    public init(motion: EchoMotion) {
        let scale = motion.durationScale
        fadeOutDuration = 0.12 * scale
        fadeInDuration = 0.22 * scale
        fadeOut = .easeOut(duration: fadeOutDuration)
        fadeIn = .easeOut(duration: fadeInDuration)
        totalDuration = fadeOutDuration + 0.28 * scale + fadeInDuration
    }
}

extension EchoMotion {
    /// A dock switch moves the card's edge to the new section's size: smooth, no overshoot.
    public var dockEdge: Animation { reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.28 * durationScale) }

    /// Rows leaving the tree fade out quickly, so they never sit under rows moving over them.
    public var rowRemoval: Animation { .easeOut(duration: 0.1 * durationScale) }
}
