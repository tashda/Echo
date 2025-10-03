import Foundation

/// Comprehensive error handling for database operations

public enum DatabaseError: Error, LocalizedError, Sendable {
    case connectionFailed (String)
    case authenticationFailed (String)
    case networkTimeout (String)
    case tlsError (String)
    case queryError (String)
    case invalidQuery (String)
    case columnNotFound (String)
    case dataConversionError (String)
    case transactionError (String)
    case protocolError (String)
    case unknownError (String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed (let message):
            return "Connection Failed: \(message)"
        case .authenticationFailed (let message):
            return "Authentication Failed: \(message)"
        case .networkTimeout (let message):
            return "Network Timeout: \(message)"
        case .tlsError (let message):
            return "TLS/SSL Error: \(message)"
        case .queryError (let message):
            return "Query Error: \(message)"
        case .invalidQuery (let message):
            return "Invalid Query: \(message)"
        case .columnNotFound (let message):
            return "Column Not Found: \(message)"
        case .dataConversionError (let message):
            return "Data Conversion Error: \(message)"
        case .transactionError (let message):
            return "Transaction Error: \(message)"
        case .protocolError (let message):
            return "Protocol Error: \(message)"
        case .unknownError (let message):
            return "Unknown Error: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Check your connection settings, ensure the server is running, and verify network connectivity."
        case .authenticationFailed:
            return "Verify your username and password are correct."
        case .networkTimeout:
            return "Check your network connection and try again."
        case .tlsError:
            return "Verify TLS/SSL settings match your server configuration."
        case .queryError:
            return "Check your SQL syntax and ensure all referenced tables and columns exist."
        case .invalidQuery:
            return "Review your SQL query for syntax errors."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }

    /// Creates a DatabaseError from a generic Error
    static func from(_ error: Error) -> DatabaseError {
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("connection") && errorDescription.contains("refused") {
            return .connectionFailed("Connection refused - check if the server is running")
        } else if errorDescription.contains("authentication") || errorDescription.contains("password") {
            return .authenticationFailed("Invalid username or password")
        } else if errorDescription.contains("timeout") {
            return .networkTimeout("Connection timed out")
        } else if errorDescription.contains("tls") || errorDescription.contains("ssl") {
            return .tlsError("TLS/SSL configuration error")
        } else if errorDescription.contains("syntax") {
            return .queryError("SQL syntax error")
        } else {
            return .unknownError(error.localizedDescription)
        }
    }
}

/// Connection state with detailed error information

public enum ConnectionState: Sendable {
    case disconnected
    case testing
    case connecting
    case connected
    case error (DatabaseError)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    var isLoading: Bool {
        switch self {
        case .testing, .connecting:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        if case .error (let dbError) = self {
            return dbError.localizedDescription
        }
        return nil
    }
}