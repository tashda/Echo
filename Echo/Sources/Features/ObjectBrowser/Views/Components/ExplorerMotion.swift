import OSLog
import SwiftUI

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
