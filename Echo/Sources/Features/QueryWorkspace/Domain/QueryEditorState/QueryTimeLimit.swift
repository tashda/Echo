import Foundation

/// Whose query time limit applies (Echo Labs round 21, timeouts: TW2 and SL1).
enum QueryTimeLimitScope: Equatable, Sendable {
    /// The connection's own Query Time Limit.
    case connection
    /// Settings › Databases › Query time limit.
    case settings
    /// A limit set on the server (for the role or database); Echo set none.
    case server
}

/// A statement the time limit stopped (TF4: explained where the result would be).
struct QueryTimeLimitStop: Equatable, Sendable {
    /// The limit in seconds, when known (the server's is read after the stop).
    var seconds: TimeInterval?
    var scope: QueryTimeLimitScope

    /// "Stopped after 30 s: the statement limit for this connection."
    var explanation: String {
        let after = seconds.map { "Stopped after \(QueryTimeLimitStop.format($0))" } ?? "Stopped by a time limit"
        switch scope {
        case .connection: return "\(after): the statement limit for this connection."
        case .settings: return "\(after): your default limit in Settings."
        case .server:
            return seconds.map { "Stopped by the server's limit of \(QueryTimeLimitStop.format($0)) (set for your role or database)." }
                ?? "Stopped by a time limit set on the server."
        }
    }

    /// "30 s", "5 min", "1 min 30 s".
    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        let minutes = total / 60, rest = total % 60
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }

    /// PostgreSQL's message when statement_timeout stops a statement (SQLSTATE 57014).
    static func isStatementTimeout(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("canceling statement due to statement timeout")
    }

    /// `statement_timeout` as the server shows it: "30s", "5min", "250ms", "0", or bare milliseconds.
    static func parseServerSetting(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        let digits = trimmed.prefix { $0.isNumber || $0 == "." }
        guard let value = Double(digits), value > 0 else { return nil }
        switch trimmed.dropFirst(digits.count).trimmingCharacters(in: .whitespaces) {
        case "", "ms": return value / 1000
        case "s": return value
        case "min": return value * 60
        case "h": return value * 3600
        case "d": return value * 86_400
        default: return nil
        }
    }
}

/// A running statement waiting for a lock (LF3: the footer says so; the holder shows on hover).
struct QueryLockWait: Equatable, Sendable {
    let holderPID: Int32
    let holderUser: String?
    let holderApplication: String?
    let holderQuery: String?
    let holderState: String?
    let holderTransactionStartedAt: Date?

    /// The status pill's hover text.
    func summary(now: Date = Date()) -> String {
        var lines = ["Waiting for a lock held by \(holderUser ?? "another session") · pid \(holderPID)"]
        if let application = holderApplication, !application.isEmpty { lines.append(application) }
        if let query = holderQuery, !query.isEmpty { lines.append(query) }
        if let state = holderState, let started = holderTransactionStartedAt {
            let minutes = Int(now.timeIntervalSince(started) / 60)
            lines.append("\(state), in a transaction for \(minutes < 1 ? "less than a minute" : "\(minutes) min")")
        }
        return lines.joined(separator: "\n")
    }
}

extension QueryEditorState {
    /// How long a statement runs before Echo starts asking whether it waits for a lock.
    static let lockWaitCheckDelay: Duration = .seconds(2)

    /// Starts checking, once a second after the first two, whether the running statement waits for a
    /// lock. The check runs on another connection (see `lockWaitProvider`), so the statement itself
    /// is not slowed, and quick statements are never checked.
    func startLockWaitWatch() {
        lockWaitTask?.cancel()
        lockWait = nil
        guard let provider = lockWaitProvider else { return }
        lockWaitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.lockWaitCheckDelay)
            while !Task.isCancelled, self?.isExecuting == true {
                let wait = await provider()
                guard !Task.isCancelled, let self, self.isExecuting else { break }
                if self.lockWait != wait { self.lockWait = wait }
                try? await Task.sleep(for: .seconds(1))
            }
            self?.lockWait = nil
        }
    }

    func stopLockWaitWatch() {
        lockWaitTask?.cancel()
        lockWaitTask = nil
        lockWait = nil
    }

    /// A failed run: was it the time limit? Then say whose, reading the server's limit when Echo set none.
    func noteTimeLimitStopIfNeeded(_ message: String) {
        guard QueryTimeLimitStop.isStatementTimeout(message) else { return }
        var stop = QueryTimeLimitStop(seconds: timeLimit, scope: timeLimitScope ?? .server)
        timeLimitStop = stop
        guard stop.scope == .server, let provider = serverTimeLimitProvider else { return }
        Task { @MainActor [weak self] in
            stop.seconds = await provider()
            if self?.timeLimitStop?.scope == .server { self?.timeLimitStop = stop }
        }
    }
}
