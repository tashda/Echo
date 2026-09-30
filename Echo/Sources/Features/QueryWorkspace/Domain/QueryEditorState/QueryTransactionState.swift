import Foundation

/// A query tab's transaction (Echo Labs round 21, transaction state, accepted), as Echo follows it
/// from the statements the tab runs (K1): no extra round trip to the server.
enum QueryTransactionState: Equatable, Sendable {
    case none
    /// Inside BEGIN … COMMIT since `since`.
    case open(since: Date)
    /// A statement in the transaction failed; only ROLLBACK helps (F1).
    case failed(since: Date)

    var since: Date? {
        switch self {
        case .none: nil
        case .open(let since), .failed(let since): since
        }
    }

    /// The reminder's idle threshold (R3).
    static let reminderIdleTime: TimeInterval = 15 * 60
}

/// What the tab's session reports, in Echo's words.
enum QueryTransactionStatus: Sendable {
    case idle, open, failed
}

extension QueryEditorState {
    /// Reads the tab's transaction state after a run. The provider reads Echo's own tracking of the
    /// pinned session, so this costs nothing on the server.
    func refreshTransactionState() {
        guard let provider = transactionStatusProvider else { return }
        Task { @MainActor [weak self] in
            let status = await provider()
            self?.applyTransactionStatus(status)
        }
    }

    func applyTransactionStatus(_ status: QueryTransactionStatus?) {
        transactionLastActivity = Date()
        transactionReminderSent = false
        switch status {
        case .open?:
            transactionState = .open(since: transactionState.since ?? Date())
        case .failed?:
            transactionState = .failed(since: transactionState.since ?? Date())
        case .idle?, nil:
            transactionState = .none
        }
    }
}
