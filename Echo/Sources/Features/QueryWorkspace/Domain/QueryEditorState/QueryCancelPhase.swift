import Foundation

/// Between pressing Cancel and the query ending (Echo Labs round 21, cancelling a query).
enum QueryCancelPhase: Equatable, Sendable {
    /// The cancel was sent; the footer says Cancelling (CX3).
    case cancelling
    /// No answer after 5 s; the results offer Force Stop (CS2).
    case notStopping

    /// How long to wait for the server before offering Force Stop.
    static let forceStopDelay: Duration = .seconds(5)
}

extension QueryEditorState {
    /// TX1: the cancelled statement was inside a transaction, which the server now treats as failed.
    func noteCancelledInsideTransaction() {
        runNote = runNote?.needingRollback()
        appendMessage(
            message: "The transaction now needs ROLLBACK: a cancelled statement fails the transaction it was in.",
            severity: .warning,
            category: "Transaction"
        )
    }

    /// Force Stop closed the connection.
    func noteForceStopped(transactionWasOpen: Bool) {
        appendMessage(
            message: transactionWasOpen
                ? "Force stopped: Echo closed the connection. The open transaction was rolled back; the next run uses a new session."
                : "Force stopped: Echo closed the connection. The next run uses a new session.",
            severity: .warning,
            category: "Query Execution"
        )
    }
}
