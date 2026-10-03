import SwiftUI
import Combine
import HatchCore

enum Format {
    /// "20m", "2h", "1d", "3w": short ages for lists.
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 14 { return "\(days)d" }
        let weeks = days / 7
        if weeks < 9 { return "\(weeks)w" }
        return "\(days / 30)mo"
    }

    /// "2h ago" for places with room.
    static func ago(_ date: Date) -> String {
        let short = relative(date)
        return short == "now" ? "just now" : "\(short) ago"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// "118k" for token counts.
    static func tokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1000 { return "\(n / 1000)k" }
        return "\(n)"
    }

    /// The number shown for a ticket: "#151" once it exists on GitHub, "new-12" before that.
    static func number(_ t: Ticket) -> String { t.displayNumber }

    /// Plural helper: "1 question", "2 questions".
    static func count(_ n: Int, _ noun: String) -> String {
        n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }
}

/// Reloads a screen when the app state changes, when the project changes, and every few seconds (agents write through the CLI).
struct AutoReload: ViewModifier {
    @EnvironmentObject var state: AppState
    let seconds: Double
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { action() }
            .onChange(of: state.revision) { _, _ in action() }
            .onChange(of: state.selectedProjectKey) { _, _ in action() }
            .onReceive(Timer.publish(every: seconds, on: .main, in: .common).autoconnect()) { _ in action() }
    }
}

extension View {
    func autoReload(every seconds: Double = 5, _ action: @escaping () -> Void) -> some View {
        modifier(AutoReload(seconds: seconds, action: action))
    }
}
