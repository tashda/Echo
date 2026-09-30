import Foundation

/// QE2 (design board, 2026-09-30): after a run, what happened, shown at the end of what ran and
/// gone as soon as the script is edited.
nonisolated struct QueryRunNote: Equatable, Sendable {
    let range: NSRange
    let text: String
    /// The whole message, for the tooltip.
    let detail: String
    let isError: Bool
    /// Cancelled: drawn in orange (round 21, cancel CR2).
    var isWarning = false

    static func success(range: NSRange?, rows: Int, hasResults: Bool, duration: TimeInterval?) -> QueryRunNote? {
        guard let range else { return nil }
        let time = duration.map(formatted) ?? ""
        let rowText = hasResults ? "\(rows.formatted(.number)) \(rows == 1 ? "row" : "rows")" : "Done"
        let text = time.isEmpty ? "✓ \(rowText)" : "✓ \(rowText) · \(time)"
        return QueryRunNote(range: range, text: text, detail: text, isError: false)
    }

    static func failure(range: NSRange?, message: String) -> QueryRunNote? {
        guard let range else { return nil }
        let firstLine = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        let limit = 80
        let short = firstLine.count > limit ? String(firstLine.prefix(limit)).trimmingCharacters(in: .whitespaces) : firstLine
        return QueryRunNote(range: range, text: short, detail: message, isError: true)
    }

    /// RN1 (round 21, accepted): `! Error` at the statement; the mark carries the message, and the
    /// tooltip the whole of it. Settings can show the full message instead (owner's note).
    static func shortFailure(range: NSRange?, message: String) -> QueryRunNote? {
        guard let range else { return nil }
        return QueryRunNote(range: range, text: "! Error", detail: message, isError: true)
    }

    /// CR2: `Cancelled after 3.2 s · 1,200 rows`, at the statement.
    static func cancelled(range: NSRange?, duration: TimeInterval?, rows: Int) -> QueryRunNote? {
        guard let range else { return nil }
        let text = cancelledText(duration: duration, rows: rows)
        return QueryRunNote(range: range, text: text, detail: text, isError: false, isWarning: true)
    }

    static func cancelledText(duration: TimeInterval?, rows: Int) -> String {
        var text = "Cancelled"
        if let duration { text += " after \(formatted(duration))" }
        if rows > 0 { text += " · \(rows.formatted(.number)) \(rows == 1 ? "row" : "rows")" }
        return text
    }

    /// TX1: the cancelled statement was inside a transaction, which is now aborted.
    func needingRollback() -> QueryRunNote {
        let suffix = " · The transaction now needs ROLLBACK"
        return QueryRunNote(range: range, text: text + suffix, detail: detail + suffix, isError: isError, isWarning: isWarning)
    }

    static func formatted(_ duration: TimeInterval) -> String {
        if duration < 1 { return "\(Int((duration * 1000).rounded())) ms" }
        if duration < 60 { return String(format: "%.1f s", duration) }
        return "\(Int(duration) / 60) min \(Int(duration) % 60) s"
    }
}
