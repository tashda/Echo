import Foundation
import Testing
@testable import Echo

@Suite("DatabaseError")
struct DatabaseErrorTests {

    // MARK: - errorDescription

    @Test func connectionFailedDescription() {
        let error = DatabaseError.connectionFailed("server unreachable")
        #expect(error.errorDescription == "Connection Failed: server unreachable")
    }

    @Test func authenticationFailedDescription() {
        let error = DatabaseError.authenticationFailed("bad password")
        #expect(error.errorDescription == "Authentication Failed: bad password")
    }

    @Test func networkTimeoutDescription() {
        let error = DatabaseError.networkTimeout("30s elapsed")
        #expect(error.errorDescription == "Network Timeout: 30s elapsed")
    }

    @Test func tlsErrorDescription() {
        let error = DatabaseError.tlsError("certificate expired")
        #expect(error.errorDescription == "TLS/SSL Error: certificate expired")
    }

    @Test func queryErrorDescription() {
        let error = DatabaseError.queryError("syntax error near SELECT")
        #expect(error.errorDescription == "Query Error: syntax error near SELECT")
    }

    @Test func invalidQueryDescription() {
        let error = DatabaseError.invalidQuery("missing semicolon")
        #expect(error.errorDescription == "Invalid Query: missing semicolon")
    }

    @Test func columnNotFoundDescription() {
        let error = DatabaseError.columnNotFound("age")
        #expect(error.errorDescription == "Column Not Found: age")
    }

    @Test func dataConversionErrorDescription() {
        let error = DatabaseError.dataConversionError("cannot convert text to int")
        #expect(error.errorDescription == "Data Conversion Error: cannot convert text to int")
    }

    @Test func transactionErrorDescription() {
        let error = DatabaseError.transactionError("deadlock detected")
        #expect(error.errorDescription == "Transaction Error: deadlock detected")
    }

    @Test func protocolErrorDescription() {
        let error = DatabaseError.protocolError("unexpected packet")
        #expect(error.errorDescription == "Protocol Error: unexpected packet")
    }

    @Test func unknownErrorDescription() {
        let error = DatabaseError.unknownError("something went wrong")
        #expect(error.errorDescription == "Unknown Error: something went wrong")
    }

    @Test func errorDescriptionWithEmptyMessage() {
        let error = DatabaseError.connectionFailed("")
        #expect(error.errorDescription == "Connection Failed: ")
    }

    // MARK: - recoverySuggestion

    @Test func connectionFailedRecovery() {
        let error = DatabaseError.connectionFailed("msg")
        #expect(error.recoverySuggestion?.contains("connection settings") == true)
    }

    @Test func authenticationFailedRecovery() {
        let error = DatabaseError.authenticationFailed("msg")
        #expect(error.recoverySuggestion?.contains("username and password") == true)
    }

    @Test func networkTimeoutRecovery() {
        let error = DatabaseError.networkTimeout("msg")
        #expect(error.recoverySuggestion?.contains("network connection") == true)
    }

    @Test func tlsErrorRecovery() {
        let error = DatabaseError.tlsError("msg")
        #expect(error.recoverySuggestion?.contains("TLS/SSL settings") == true)
    }

    @Test func queryErrorRecovery() {
        let error = DatabaseError.queryError("msg")
        #expect(error.recoverySuggestion?.contains("SQL syntax") == true)
    }

    @Test func invalidQueryRecovery() {
        let error = DatabaseError.invalidQuery("msg")
        #expect(error.recoverySuggestion?.contains("syntax errors") == true)
    }

    @Test func columnNotFoundRecoveryFallsToDefault() {
        let error = DatabaseError.columnNotFound("msg")
        #expect(error.recoverySuggestion?.contains("try again") == true)
    }

    @Test func dataConversionErrorRecoveryFallsToDefault() {
        let error = DatabaseError.dataConversionError("msg")
        #expect(error.recoverySuggestion?.contains("try again") == true)
    }

    @Test func transactionErrorRecoveryFallsToDefault() {
        let error = DatabaseError.transactionError("msg")
        #expect(error.recoverySuggestion?.contains("try again") == true)
    }

    @Test func protocolErrorRecoveryFallsToDefault() {
        let error = DatabaseError.protocolError("msg")
        #expect(error.recoverySuggestion?.contains("try again") == true)
    }

    @Test func unknownErrorRecoveryFallsToDefault() {
        let error = DatabaseError.unknownError("msg")
        #expect(error.recoverySuggestion?.contains("try again") == true)
    }

    // MARK: - DatabaseError.from(_:)

    @Test func fromConnectionRefusedError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Connection refused by server"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .connectionFailed(let msg) = dbError else {
            Issue.record("Expected connectionFailed, got \(dbError)")
            return
        }
        #expect(msg.contains("Connection refused"))
    }

    @Test func fromAuthenticationError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Authentication failed for user"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .authenticationFailed = dbError else {
            Issue.record("Expected authenticationFailed, got \(dbError)")
            return
        }
    }

    @Test func fromPasswordError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid password provided"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .authenticationFailed = dbError else {
            Issue.record("Expected authenticationFailed, got \(dbError)")
            return
        }
    }

    @Test func fromTimeoutError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Operation timeout exceeded"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .networkTimeout = dbError else {
            Issue.record("Expected networkTimeout, got \(dbError)")
            return
        }
    }

    @Test func fromTLSError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "TLS handshake failed"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .tlsError = dbError else {
            Issue.record("Expected tlsError, got \(dbError)")
            return
        }
    }

    @Test func fromSSLError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "SSL certificate verification failed"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .tlsError = dbError else {
            Issue.record("Expected tlsError, got \(dbError)")
            return
        }
    }

    @Test func fromSyntaxError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "SQL syntax error near line 5"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .queryError = dbError else {
            Issue.record("Expected queryError, got \(dbError)")
            return
        }
    }

    @Test func fromUnknownError() {
        let nsError = NSError(
            domain: "test",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Something completely unexpected"]
        )
        let dbError = DatabaseError.from(nsError)
        guard case .unknownError(let msg) = dbError else {
            Issue.record("Expected unknownError, got \(dbError)")
            return
        }
        #expect(msg == "Something completely unexpected")
    }

    @Test func fromErrorPreservesLocalizedDescription() {
        struct CustomError: LocalizedError {
            var errorDescription: String? { "Custom error occurred" }
        }
        let dbError = DatabaseError.from(CustomError())
        guard case .unknownError(let msg) = dbError else {
            Issue.record("Expected unknownError")
            return
        }
        #expect(msg == "Custom error occurred")
    }

    // MARK: - LocalizedError conformance

    @Test func databaseErrorConformsToLocalizedError() {
        let error: any LocalizedError = DatabaseError.connectionFailed("test")
        #expect(error.errorDescription != nil)
    }

    @Test func databaseErrorConformsToError() {
        let error: any Error = DatabaseError.queryError("test")
        #expect(error.localizedDescription.contains("Query Error"))
    }
}

@Suite("ConnectionState")
struct ConnectionStateTests {

    @Test func disconnectedIsNotConnected() {
        let state = ConnectionState.disconnected
        #expect(!state.isConnected)
    }

    @Test func testingIsNotConnected() {
        let state = ConnectionState.testing
        #expect(!state.isConnected)
    }

    @Test func connectingIsNotConnected() {
        let state = ConnectionState.connecting
        #expect(!state.isConnected)
    }

    @Test func connectedIsConnected() {
        let state = ConnectionState.connected
        #expect(state.isConnected)
    }

    @Test func errorIsNotConnected() {
        let state = ConnectionState.error(.connectionFailed("test"))
        #expect(!state.isConnected)
    }

    // MARK: - isLoading

    @Test func testingIsLoading() {
        let state = ConnectionState.testing
        #expect(state.isLoading)
    }

    @Test func connectingIsLoading() {
        let state = ConnectionState.connecting
        #expect(state.isLoading)
    }

    @Test func disconnectedIsNotLoading() {
        let state = ConnectionState.disconnected
        #expect(!state.isLoading)
    }

    @Test func connectedIsNotLoading() {
        let state = ConnectionState.connected
        #expect(!state.isLoading)
    }

    @Test func errorIsNotLoading() {
        let state = ConnectionState.error(.queryError("test"))
        #expect(!state.isLoading)
    }

    // MARK: - errorDescription

    @Test func disconnectedHasNoErrorDescription() {
        #expect(ConnectionState.disconnected.errorDescription == nil)
    }

    @Test func testingHasNoErrorDescription() {
        #expect(ConnectionState.testing.errorDescription == nil)
    }

    @Test func connectingHasNoErrorDescription() {
        #expect(ConnectionState.connecting.errorDescription == nil)
    }

    @Test func connectedHasNoErrorDescription() {
        #expect(ConnectionState.connected.errorDescription == nil)
    }

    @Test func errorStateHasErrorDescription() {
        let state = ConnectionState.error(.connectionFailed("server down"))
        let desc = state.errorDescription
        #expect(desc != nil)
        #expect(desc?.contains("Connection Failed") == true)
    }

    @Test func errorStateWithDifferentErrors() {
        let tlsState = ConnectionState.error(.tlsError("cert issue"))
        #expect(tlsState.errorDescription?.contains("TLS/SSL Error") == true)

        let authState = ConnectionState.error(.authenticationFailed("bad creds"))
        #expect(authState.errorDescription?.contains("Authentication Failed") == true)
    }
}
