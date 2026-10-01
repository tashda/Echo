import Foundation

/// Where an event happened, so its toast and history row can link back (plan N3).
struct NotificationContext: Codable, Equatable, Sendable {
    var serverName: String?
    /// The saved connection, stable across launches.
    var connectionID: UUID?
    /// The workspace tab; only meaningful while that tab is open.
    var tabID: UUID?
    /// An extra button on the toast and history row, offered while it still applies.
    var action: NotificationAction?
}

/// A button a notification can carry besides Open Tab and Copy.
enum NotificationAction: String, Codable, Equatable, Sendable {
    /// Reconnect a query tab whose connection dropped with a transaction open (round 21, RC2).
    case reconnectTab
    /// Put the failed tab's editor on the error (round 21 J1, owner's note).
    case goToError

    var title: String {
        switch self {
        case .reconnectTab: "Reconnect"
        case .goToError: "Go to Error"
        }
    }
}

/// One event in the notification history. Every event is recorded, even when its toast is muted.
struct NotificationRecord: Codable, Identifiable, Equatable, Sendable {
    enum Severity: String, Codable, Sendable {
        case success, info, warning, error
    }

    let id: UUID
    let date: Date
    let category: NotificationCategory
    let message: String
    let severity: Severity
    var context: NotificationContext?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        category: NotificationCategory,
        message: String,
        severity: Severity,
        context: NotificationContext? = nil
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.message = message
        self.severity = severity
        self.context = context
    }
}

extension NotificationRecord {
    /// The first line of a compact card; see `NotificationMessageParts`.
    var headline: String { NotificationMessageParts(message).headline }

    /// What follows the headline, shown when the card is opened.
    var detail: String? { NotificationMessageParts(message).detail }
}

/// The history card's filters.
enum NotificationHistoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case errors = "Errors"
    case connection = "Connection"
    case queries = "Queries"
    case jobs = "Jobs"

    var id: String { rawValue }

    func includes(_ record: NotificationRecord) -> Bool {
        switch self {
        case .all: true
        case .errors: record.severity == .error
        case .connection: record.category.group == .connection
        case .queries: record.category == .queryFailed
        case .jobs: record.category.group == .jobs
        }
    }
}
