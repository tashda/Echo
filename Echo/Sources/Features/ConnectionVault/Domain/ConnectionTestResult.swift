import Foundation

public struct ConnectionTestResult: Sendable {
    public let isSuccessful: Bool
    public let message: String
    public let responseTime: TimeInterval?
    public let serverVersion: String?
    /// A setting that resolves the failure, offered as a button by the result (round 22, TE1).
    public var fix: ConnectionTestFix?
    /// A problem with the Key Password row, shown under it as well as in the result line
    /// (round 23, client key: KE1).
    public var keyPasswordIssue: String?
    /// One line per server when a PostgreSQL connection has several (round 23, failover: TS1).
    public var serverLines: [String] = []

    public init(isSuccessful: Bool, message: String, responseTime: TimeInterval?, serverVersion: String?, fix: ConnectionTestFix? = nil,
                keyPasswordIssue: String? = nil, serverLines: [String] = []) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.responseTime = responseTime
        self.serverVersion = serverVersion
        self.fix = fix
        self.keyPasswordIssue = keyPasswordIssue
        self.serverLines = serverLines
    }

    public var success: Bool { isSuccessful }

    public var details: String {
        var parts: [String] = []
        if let responseTime {
            parts.append(String(format: "%.3fs", responseTime))
        }
        if let serverVersion, !serverVersion.isEmpty {
            parts.append(serverVersion)
        }
        return parts.isEmpty ? message : parts.joined(separator: " • ")
    }
}

/// The one setting that resolves a failed connection test.
public enum ConnectionTestFix: Sendable, Equatable {
    /// The certificate is untrusted, self-signed or out of date: turn on Trust Server Certificate.
    case trustCertificate
    /// The certificate is for another name: set Host Name In Certificate to it.
    case hostNameInCertificate(String)
    /// The server offers nothing newer than TLS 1.0 or 1.1: turn on Allow TLS 1.0.
    case allowLegacyTLS
    /// There is no Kerberos ticket, or it expired: open Ticket Viewer (round 23, Kerberos: NT1).
    case openTicketViewer
    /// Kerberos was chosen but the server asks for a password: switch the mechanism (KF1).
    case usePassword

    public var title: String {
        switch self {
        case .trustCertificate: "Trust This Certificate"
        case .hostNameInCertificate(let name): "Use Host Name “\(name)”"
        case .allowLegacyTLS: "Allow TLS 1.0"
        case .openTicketViewer: "Open Ticket Viewer"
        case .usePassword: "Use Password"
        }
    }
}
