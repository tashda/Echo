import Foundation
import SQLServerKit

/// Comprehensive error handling for database operations

public enum DatabaseError: Error, LocalizedError, Sendable {
    case connectionFailed(String, underlyingError: (any Error & Sendable)? = nil)
    case authenticationFailed(String, underlyingError: (any Error & Sendable)? = nil)
    case networkTimeout(String, underlyingError: (any Error & Sendable)? = nil)
    case tlsError(String, underlyingError: (any Error & Sendable)? = nil)
    case queryError(String, underlyingError: (any Error & Sendable)? = nil)
    case invalidQuery(String)
    case columnNotFound(String)
    case dataConversionError(String)
    case transactionError(String, underlyingError: (any Error & Sendable)? = nil)
    case protocolError(String, underlyingError: (any Error & Sendable)? = nil)
    case unknownError(String, underlyingError: (any Error & Sendable)? = nil)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message, _):
            return "Connection Failed: \(message)"
        case .authenticationFailed(let message, _):
            return "Authentication Failed: \(message)"
        case .networkTimeout(let message, _):
            return "Network Timeout: \(message)"
        case .tlsError(let message, _):
            return "TLS/SSL Error: \(message)"
        case .queryError(let message, _):
            return "Query Error: \(message)"
        case .invalidQuery(let message):
            return "Invalid Query: \(message)"
        case .columnNotFound(let message):
            return "Column Not Found: \(message)"
        case .dataConversionError(let message):
            return "Data Conversion Error: \(message)"
        case .transactionError(let message, _):
            return "Transaction Error: \(message)"
        case .protocolError(let message, _):
            return "Protocol Error: \(message)"
        case .unknownError(let message, _):
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

    /// Creates a DatabaseError from a generic Error, preserving the original error for debugging.
    static func from(_ error: any Error) -> DatabaseError {
        // Typed conversion: SQL Server errors
        if let sqlError = error as? SQLServerError {
            return from(sqlServerError: sqlError)
        }

        // Already a DatabaseError — pass through
        if let dbError = error as? DatabaseError {
            return dbError
        }

        // Fallback: classify by message content, preserving the original error
        let sendable = error as (any Error & Sendable)
        let desc = error.localizedDescription.lowercased()

        if desc.contains("connection") && desc.contains("refused") {
            return .connectionFailed("Connection refused - check if the server is running", underlyingError: sendable)
        } else if desc.contains("authentication") || desc.contains("password") || desc.contains("login failed") {
            return .authenticationFailed(error.localizedDescription, underlyingError: sendable)
        } else if desc.contains("timeout") {
            return .networkTimeout(error.localizedDescription, underlyingError: sendable)
        } else if desc.contains("tls") || desc.contains("ssl") || desc.contains("certificate") {
            return .tlsError(error.localizedDescription, underlyingError: sendable)
        } else if desc.contains("syntax") {
            return .queryError(error.localizedDescription, underlyingError: sendable)
        } else {
            return .unknownError(error.localizedDescription, underlyingError: sendable)
        }
    }

    /// Creates a DatabaseError from a SQL Server specific error.
    static func from(sqlServerError error: SQLServerError) -> DatabaseError {
        let message = error.localizedDescription
        let sendable = error as (any Error & Sendable)

        switch error {
        case .clientShutdown, .connectionClosed:
            return .connectionFailed(message, underlyingError: sendable)
        case .authenticationFailed:
            return .authenticationFailed(message, underlyingError: sendable)
        case .timeout:
            return .networkTimeout(message, underlyingError: sendable)
        case .sqlExecutionError, .deadlockDetected:
            return .queryError(message, underlyingError: sendable)
        case .protocolError:
            return .protocolError(message, underlyingError: sendable)
        case .transient:
            return .connectionFailed(message, underlyingError: sendable)
        case .databaseDoesNotExist:
            return .queryError(message, underlyingError: sendable)
        case .invalidArgument:
            return .invalidQuery(message)
        case .unsupportedPlatform, .unknown:
            return .unknownError(message, underlyingError: sendable)
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