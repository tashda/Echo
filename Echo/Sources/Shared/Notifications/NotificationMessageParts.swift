import Foundation

/// A notification message split into a one-line title and its details: the message up to its
/// first ": " ("Query 1 failed", "Backup failed for sales") and what follows. Toasts and the
/// history's cards show them this way (rounds 17 and 18).
nonisolated struct NotificationMessageParts: Equatable, Sendable {
    let headline: String
    let detail: String?

    init(_ message: String) {
        guard let range = message.range(of: ": ") else {
            headline = message
            detail = nil
            return
        }
        headline = String(message[..<range.lowerBound])
        let rest = message[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        detail = rest.isEmpty ? nil : rest
    }
}
