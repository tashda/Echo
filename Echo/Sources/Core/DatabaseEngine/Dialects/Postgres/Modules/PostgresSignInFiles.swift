import Foundation
#if os(macOS)
import AppKit
#endif
import PostgresWire

/// The user's Kerberos ticket as the connection sheet shows it (Echo Labs round 23, KT1, KU1).
enum KerberosTicketStatus: Equatable, Sendable {
    case valid(principal: String, expiresAt: Date?)
    case expired(principal: String?)
    case none
    case unavailable

    /// Reads the ticket from the credential cache (local only; never asks the KDC).
    static func current() -> KerberosTicketStatus {
        switch PostgresKerberos.currentTicket() {
        case .valid(let principal, let expiresAt): .valid(principal: principal, expiresAt: expiresAt)
        case .expired(let principal): .expired(principal: principal)
        case .none: .none
        case .unavailable: .unavailable
        }
    }

    /// "alice" for alice@CORP.EXAMPLE.COM: the role the ticket usually signs in as.
    var userName: String? {
        switch self {
        case .valid(let principal, _), .expired(let principal?):
            principal.split(separator: "@").first.map(String.init)
        default:
            nil
        }
    }

    /// Opens Ticket Viewer, where a Mac user gets or renews a ticket (NT1).
    @MainActor static func openTicketViewer() {
        #if os(macOS)
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Ticket Viewer.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        #endif
    }
}

/// Client certificate files (round 23, client key: KW1, PF2).
enum ClientCertificateFiles {
    /// A .p12/.pfx file holds the certificate and its key, so the Client Key row is not needed.
    static func isBundle(_ path: String?) -> Bool {
        path.map(PostgresClientCertificate.isPKCS12) ?? false
    }

    /// Whether the key (or .p12 file) is protected by a password, read from the file.
    static func keyNeedsPassword(certificatePath: String?, keyPath: String?) -> Bool {
        if let certificatePath, isBundle(certificatePath) {
            return PostgresClientCertificate.keyNeedsPassword(atPath: certificatePath)
        }
        guard let keyPath, !keyPath.isEmpty else { return false }
        return PostgresClientCertificate.keyNeedsPassword(atPath: keyPath)
    }
}
