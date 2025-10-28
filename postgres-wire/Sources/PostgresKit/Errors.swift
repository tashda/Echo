import Foundation

public enum PostgresKitError: Error, Sendable {
    case connectionClosed
    case cancelled
    case invalidConfiguration(String)
    case queryFailed(String)
    case notSupported(String)
}
