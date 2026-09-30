import OSLog
import SwiftUI

/// The dock switch's timing (round 19, S3), scaled by the speed setting: the veil fades in, the
/// section swaps under it while the card's edge moves, then the veil fades out.
struct ExplorerDockSwitchTiming {
    let fadeOutDuration: Double
    let fadeInDuration: Double
    let fadeOut: Animation
    let fadeIn: Animation

    init(motion: EchoMotion) {
        let scale = motion.durationScale
        fadeOutDuration = 0.12 * scale
        fadeInDuration = 0.22 * scale
        fadeOut = .easeOut(duration: fadeOutDuration)
        fadeIn = .easeOut(duration: fadeInDuration)
        totalDuration = fadeOutDuration + 0.28 * scale + fadeInDuration
    }

    /// Fade out, the edge moving, fade in: how long the window is held still (`WindowDragPause`).
    let totalDuration: Double
}

extension EchoMotion {
    /// A dock switch moves the card's edge to the new section's size: smooth, no overshoot.
    var dockEdge: Animation { reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.28 * durationScale) }

    /// Rows leaving the tree fade out quickly, so they never sit under rows moving over them.
    var rowRemoval: Animation { .easeOut(duration: 0.1 * durationScale) }
}

/// DEBUG timing marks for Explorer animations: a log line (category `motion`) and an Instruments
/// point of interest, so a recording can be lined up with what the code did.
enum ExplorerMotionLog {
    #if DEBUG
    private static let logger = Logger(subsystem: "dev.echodb.echo", category: "motion")
    private static let signposter = OSSignposter(subsystem: "dev.echodb.echo", category: .pointsOfInterest)
    #endif

    static func mark(_ event: StaticString, _ connectionID: UUID) {
        #if DEBUG
        signposter.emitEvent(event)
        logger.debug("\(event, privacy: .public) \(connectionID.uuidString.prefix(8), privacy: .public) \(Date().timeIntervalSince1970, format: .fixed(precision: 3), privacy: .public)")
        #endif
    }
}
