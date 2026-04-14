import Foundation

/// Hybrid Logical Clock for monotonic timestamp generation.
///
/// Combines wall-clock time with a logical counter to guarantee monotonicity
/// even when the system clock drifts or multiple events occur within the same
/// millisecond. Used as the ordering key for last-writer-wins conflict resolution.
///
/// The HLC value is a 64-bit unsigned integer representing milliseconds since epoch,
/// with the logical counter embedded as increments above the wall clock when needed.
struct HybridClock: Sendable {
    private var lastHLC: UInt64

    init(lastHLC: UInt64 = 0) {
        self.lastHLC = lastHLC
    }

    /// Generate a new HLC timestamp guaranteed to be greater than any previous one.
    mutating func now() -> UInt64 {
        let wallClock = UInt64(Date().timeIntervalSince1970 * 1000)
        let candidate = max(wallClock, lastHLC + 1)
        lastHLC = candidate
        return candidate
    }

    /// Update the clock after receiving a remote HLC value.
    /// Ensures subsequent `now()` calls produce values greater than both
    /// the local clock and the received remote value.
    mutating func receive(remote: UInt64) {
        lastHLC = max(lastHLC, remote)
    }

    /// The most recent HLC value produced or received.
    var current: UInt64 { lastHLC }
}
