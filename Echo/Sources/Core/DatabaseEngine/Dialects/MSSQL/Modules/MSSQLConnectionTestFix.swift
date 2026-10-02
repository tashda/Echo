import Foundation
import SQLServerKit

/// Turns echo-sqlserver's TLS failure into the fix the connection sheet offers
/// (Echo Labs round 22, TE1).
enum MSSQLConnectionTestFix {
    static func fix(for error: any Error, encryptionMode: MSSQLEncryptionMode) -> ConnectionTestFix? {
        guard let sqlError = error as? SQLServerError, case .tlsFailed(let failure) = sqlError else { return nil }
        switch failure.kind {
        case .certificateNameMismatch:
            guard let name = failure.certificate?.names.first(where: { !$0.hasPrefix("*") }) else { return nil }
            return .hostNameInCertificate(name)
        case .certificateUntrusted, .certificateSelfSigned, .certificateExpired, .certificateNotYetValid:
            // Strict always checks the certificate, so trusting cannot apply.
            return encryptionMode == .strict ? nil : .trustCertificate
        case .protocolVersionTooOld, .handshakeFailed:
            guard encryptionMode != .strict, failure.message.contains("TLS 1.2") else { return nil }
            return .allowLegacyTLS
        }
    }
}
