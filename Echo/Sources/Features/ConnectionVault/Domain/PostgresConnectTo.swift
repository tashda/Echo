import Foundation

/// One more server for a PostgreSQL connection (Echo Labs round 23, failover: FH1).
struct ConnectionHost: Codable, Hashable, Sendable {
    var host: String
    /// Nil uses the connection's port.
    var port: Int?
}

/// Which server a PostgreSQL connection with several servers uses (libpq's target_session_attrs),
/// in the plain words round 23 chose (FT1). Read-write and read-only come only from pasted URLs.
enum PostgresConnectTo: String, Codable, CaseIterable, Sendable {
    case any
    case primary
    case standby
    case preferStandby = "prefer-standby"
    case readWrite = "read-write"
    case readOnly = "read-only"

    /// The items the Connect To menu offers.
    static let menuCases: [PostgresConnectTo] = [.any, .primary, .standby, .preferStandby]

    var displayName: String {
        switch self {
        case .any: "Any Server"
        case .primary: "Primary"
        case .standby: "Standby"
        case .preferStandby: "Standby, or Any if None Is Up"
        case .readWrite: "Any Writable Server"
        case .readOnly: "Any Read-Only Server"
        }
    }

    /// For the disclosure summary: "Primary", "Standby".
    var shortName: String {
        switch self {
        case .preferStandby: "Standby first"
        case .readWrite: "Writable"
        case .readOnly: "Read-only"
        default: displayName
        }
    }
}
