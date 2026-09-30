import Foundation

public struct ConnectionTestResult: Sendable {
    public let isSuccessful: Bool
    public let message: String
    public let responseTime: TimeInterval?
    public let serverVersion: String?
    /// A setting that resolves the failure, offered as a button by the result (round 22, TE1).
    public var fix: ConnectionTestFix?

    public init(isSuccessful: Bool, message: String, responseTime: TimeInterval?, serverVersion: String?, fix: ConnectionTestFix? = nil) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.responseTime = responseTime
        self.serverVersion = serverVersion
        self.fix = fix
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

    public var title: String {
        switch self {
        case .trustCertificate: "Trust This Certificate"
        case .hostNameInCertificate(let name): "Use Host Name “\(name)”"
        case .allowLegacyTLS: "Allow TLS 1.0"
        }
    }
}
