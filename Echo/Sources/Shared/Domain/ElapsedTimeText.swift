import Foundation

/// How Echo writes a running or finished query's time (round 20, K1): “5 s” under a minute, then
/// “1:05”, then “1:02:05”.
nonisolated enum ElapsedTimeText {
    static func format(_ seconds: TimeInterval) -> String {
        let whole = max(Int(seconds), 0)
        if whole < 60 { return "\(whole) s" }
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let rest = whole % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, rest) }
        return String(format: "%d:%02d", minutes, rest)
    }
}
