import Foundation

/// QE2 (design board, 2026-09-30): after a run, what happened, shown at the end of what ran and
/// gone as soon as the script is edited.
nonisolated struct QueryRunNote: Equatable, Sendable {
    let range: NSRange
    let text: String
    /// The whole message, for the tooltip.
    let detail: String
    let isError: Bool

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

    static func formatted(_ duration: TimeInterval) -> String {
        if duration < 1 { return "\(Int((duration * 1000).rounded())) ms" }
        if duration < 60 { return String(format: "%.1f s", duration) }
        return "\(Int(duration) / 60) min \(Int(duration) % 60) s"
    }
}
