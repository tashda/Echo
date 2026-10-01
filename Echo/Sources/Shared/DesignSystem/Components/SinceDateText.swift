import SwiftUI

/// How long ago something happened ("5 min, 3 sec"), live while its tab is on screen and frozen
/// at the moment it was drawn while the tab is kept mounted behind another one. A live relative
/// date ticks every second, and each tick re-lays out the window, so hidden tabs must not tick
/// (owner's choice, 2026-10-01: live only when visible).
enum SinceDateText {
    static func text(since date: Date, isLive: Bool, now: Date = .now) -> Text {
        if isLive { return Text(date, style: .relative) }
        return Text(frozen(since: date, now: now))
    }

    /// The same words as a live relative date, worked out once.
    static func frozen(since date: Date, now: Date = .now) -> String {
        let seconds = max(now.timeIntervalSince(date), 0).rounded()
        return Duration.seconds(seconds).formatted(
            .units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
