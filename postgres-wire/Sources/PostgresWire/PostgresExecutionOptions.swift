import Foundation

/// Execution mode for PostgreSQL queries at the wire level.
/// - `.auto` lets the package choose the fastest/safest path for the query
/// - `.simple` prefers simple protocol row streaming
/// - `.cursor` prefers server‑side cursors (DECLARE/FETCH)
public enum PostgresExecutionMode: Sendable, Equatable {
    case auto
    case simple
    case cursor
}

/// Per‑query execution options for PostgreSQL.
///
/// These options provide a stable surface for callers. The current
/// implementation ignores them (behavior unchanged) until the wire
/// starts routing between simple/cursor and sizing fetches internally.
public struct PostgresExecutionOptions: Sendable, Equatable {
    /// Mode selection (default `.auto`).
    public var mode: PostgresExecutionMode

    /// LIMIT threshold for mode routing (e.g., LIMIT ≤ threshold → simple).
    public var cursorThreshold: Int?

    /// Baseline fetch size when using cursor mode.
    public var fetchBaseline: Int?

    /// Aggressiveness of background fetch growth.
    public var fetchRampMultiplier: Int?

    /// Ceiling for background fetch size.
    public var fetchRampMax: Int?

    /// Advisory progress sampling throttle in milliseconds.
    public var progressThrottleMs: Int?

    public init(
        mode: PostgresExecutionMode = .auto,
        cursorThreshold: Int? = nil,
        fetchBaseline: Int? = nil,
        fetchRampMultiplier: Int? = nil,
        fetchRampMax: Int? = nil,
        progressThrottleMs: Int? = nil
    ) {
        self.mode = mode
        self.cursorThreshold = cursorThreshold
        self.fetchBaseline = fetchBaseline
        self.fetchRampMultiplier = fetchRampMultiplier
        self.fetchRampMax = fetchRampMax
        self.progressThrottleMs = progressThrottleMs
    }
}

