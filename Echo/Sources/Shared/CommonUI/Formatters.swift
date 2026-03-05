import Foundation

enum EchoFormatters {

    // MARK: - Duration

    /// Formats a TimeInterval as a human-readable duration string.
    /// - `< 1s` → "42 ms", `< 60s` → "1.25 s", `>= 60s` → "2m 15s"
    static func duration(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "—" }
        if interval < 1.0 {
            return String(format: "%.0f ms", interval * 1_000)
        } else if interval < 60 {
            return String(format: "%.2f s", interval)
        } else {
            let minutes = Int(interval / 60)
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    /// Formats elapsed whole seconds as a compact duration string.
    /// - `< 60` → "12s", `>= 60` → "2m 15s"
    static func duration(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return "\(minutes)m \(remaining)s"
    }

    // MARK: - Byte Count

    private nonisolated(unsafe) static let byteCountFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        f.countStyle = .memory
        return f
    }()

    /// Formats a byte count using IEC units (KB/MB/GB).
    static func bytes(_ count: Int) -> String {
        byteCountFormatter.string(fromByteCount: Int64(count))
    }

    /// Formats an unsigned byte count.
    static func bytes(_ count: UInt64) -> String {
        byteCountFormatter.string(fromByteCount: Int64(clamping: count))
    }

    // MARK: - Compact Number

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    /// Formats a number compactly: 1.2M, 350K, or 12,345.
    static func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 100_000 {
            return String(format: "%.0fK", Double(value) / 1_000)
        } else {
            return decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }

    // MARK: - SQL Type Abbreviation

    /// Abbreviates verbose SQL type names (e.g., "timestamp with time zone" → "timestamptz").
    static func abbreviatedSQLType(_ dataType: String) -> String {
        dataType
            .replacingOccurrences(of: " with time zone", with: "tz")
            .replacingOccurrences(of: " without time zone", with: "")
    }

    // MARK: - Relative Date

    private nonisolated(unsafe) static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// Formats a date relative to now (e.g., "2m ago", "3h ago").
    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
