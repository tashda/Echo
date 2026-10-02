import Foundation
import SQLServerKit

/// What a failed SQL Server run reported (Echo Labs round 22, errors), read from whatever error
/// reached the caller: a `SQLServerError`, or a `DatabaseError` wrapping one.
nonisolated enum SQLServerFailure {
    /// The driver's details: the first error plus every message of the batch, in order.
    static func details(of error: any Error) -> SQLServerErrorDetails? {
        sqlServerError(in: error)?.serverDetails
    }

    /// EM1: every message of the failed batch in the order the server sent them (PRINT and other
    /// informational messages, then the errors), with number, severity, state, line and procedure.
    /// Empty when the error did not come from SQL Server.
    static func serverMessages(of error: any Error) -> [ServerMessage] {
        details(of: error)?.messages.map(\.echoServerMessage) ?? []
    }

    /// FE1: the session is gone (severity 20 and above ends it, or the connection dropped), so the
    /// run takes the lost-connection path instead of showing a query error.
    static func isConnectionLost(_ error: any Error) -> Bool {
        sqlServerError(in: error)?.isConnectionLost ?? false
    }

    private static func sqlServerError(in error: any Error) -> SQLServerError? {
        if let error = error as? SQLServerError { return error }
        guard let error = error as? DatabaseError else { return nil }
        switch error {
        case .connectionFailed(_, let underlying?), .authenticationFailed(_, let underlying?),
             .networkTimeout(_, let underlying?), .tlsError(_, let underlying?),
             .queryError(_, let underlying?), .transactionError(_, let underlying?),
             .protocolError(_, let underlying?), .unknownError(_, let underlying?):
            return underlying as? SQLServerError
        default:
            return nil
        }
    }
}

extension SQLServerStreamMessage {
    /// The message in Echo's words. One mapping for every SQL Server path.
    nonisolated var echoServerMessage: ServerMessage {
        ServerMessage(
            kind: kind == .error ? .error : .info,
            number: number,
            message: message,
            state: state,
            severity: severity,
            serverName: serverName.isEmpty ? nil : serverName,
            procedureName: procedureName.isEmpty ? nil : procedureName,
            lineNumber: lineNumber,
            category: "Server Response",
            metadata: [
                "source": "echo-sqlserver",
                "token": kind == .error ? "ERROR" : "INFO"
            ]
        )
    }
}

extension ServerMessage {
    /// EM1: the header SSMS prints above a server message, e.g.
    /// `Msg 208, Level 16, State 1, Line 3` or
    /// `Msg 50000, Level 16, State 1, Procedure dbo.load_orders, Line 12`.
    /// Like SSMS, only errors get one: PRINT and informational messages (severity 10 and below,
    /// e.g. 5701 "Changed database context") show just their text.
    nonisolated var ssmsHeader: String? {
        guard kind == .error, number != 0 else { return nil }
        var parts = ["Msg \(number)", "Level \(severity)", "State \(state)"]
        if let procedureName, !procedureName.isEmpty { parts.append("Procedure \(procedureName)") }
        if let lineNumber, lineNumber > 0 { parts.append("Line \(lineNumber)") }
        return parts.joined(separator: ", ")
    }
}
