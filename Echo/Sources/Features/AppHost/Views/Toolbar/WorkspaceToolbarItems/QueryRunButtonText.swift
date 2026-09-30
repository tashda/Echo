import Foundation

/// Run's tooltip (round 20): where it will run, what a click does while running, or why it can't run.
nonisolated enum QueryRunButtonText {
    /// The state Run is in, for its tooltip.
    enum State: Equatable, Sendable {
        case ready(runsSelection: Bool)
        case nothingToRun
        case running
        case stopping
    }

    /// U1 and T1: where Run will run, what stops it, or why it can't run.
    static func help(_ state: State, database: String?, server: String?) -> String {
        switch state {
        case .stopping:
            return "Stopping"
        case .running:
            return "Stop (⌘↩)"
        case .nothingToRun:
            return "Type a query to run"
        case .ready(let runsSelection):
            let verb = runsSelection ? "Run Selection" : "Run"
            return "\(verb)\(target(database: database, server: server)) (⌘↩)"
        }
    }

    private static func target(database: String?, server: String?) -> String {
        let database = database.flatMap(nonEmpty)
        let server = server.flatMap(nonEmpty)
        switch (database, server) {
        case let (database?, server?): return " in \(database) on \(server)"
        case let (database?, nil): return " in \(database)"
        case let (nil, server?): return " on \(server)"
        case (nil, nil): return ""
        }
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
