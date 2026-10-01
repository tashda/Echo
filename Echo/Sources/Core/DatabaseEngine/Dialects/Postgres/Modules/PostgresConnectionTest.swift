import Foundation
import PostgresKit
import PostgresWire

/// The PostgreSQL side of the connection sheet's Test (Echo Labs round 23): every server of a
/// connection with several (TS1), and the one fix a failure needs (NT1, KF1, KE1).
enum PostgresConnectionTest {
    /// Tests each server, one line each ("db1 ✓ primary · db2 ✓ standby · connects to db1").
    static func testServers(
        _ connection: SavedConnection,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) async -> ConnectionTestResult {
        let configuration = PostgresNIOFactory.makeConfiguration(
            for: connection, database: connection.database, authentication: authentication, connectTimeoutSeconds: connectTimeoutSeconds)
        let started = Date()
        let probes = await PostgresClient.probeHosts(configuration: configuration)
        let elapsed = Date().timeIntervalSince(started)
        let names = displayNames(probes.map(\.host))
        let lines = zip(probes, names).map { probe, name in
            probe.role.map { "\(name) ✓ \($0.rawValue)" } ?? "\(name) ✗ \(reason(probe.error))"
        }
        let chosen = chosenIndex(probes.map(\.role), for: connection.targetSessionAttributes)
        let compact = zip(probes, names).map { probe, name in probe.role.map { "\(name) ✓ \($0.rawValue)" } ?? "\(name) ✗" }
        if let chosen {
            return ConnectionTestResult(
                isSuccessful: true,
                message: (compact + ["connects to \(names[chosen])"]).joined(separator: " · "),
                responseTime: elapsed, serverVersion: nil, serverLines: lines)
        }
        let failure = probes.compactMap(\.error).first
        var result = ConnectionTestResult(
            isSuccessful: false,
            message: "No server is \(connection.targetSessionAttributes.wanted): " + compact.joined(separator: " · "),
            responseTime: elapsed, serverVersion: nil, serverLines: lines)
        if probes.allSatisfy({ $0.role == nil }), let failure {
            result = failed(failure, connection: connection, elapsed: elapsed)
            result.serverLines = lines
        }
        return result
    }

    /// A failed test with the fix that resolves it, if there is one.
    static func failed(_ error: any Error, connection: SavedConnection, elapsed: TimeInterval?) -> ConnectionTestResult {
        var result = ConnectionTestResult(isSuccessful: false, message: error.localizedDescription, responseTime: elapsed, serverVersion: nil)
        switch (error as? PostgresKit.PostgresError)?.connectionProblem {
        case .kerberos(let kerberos)? where kerberos.kind == .noTicket || kerberos.kind == .expired:
            result = ConnectionTestResult(
                isSuccessful: false,
                message: kerberos.kind == .noTicket ? "No Kerberos ticket. Get one in Ticket Viewer, or with kinit." : "Your Kerberos ticket has expired. Renew it in Ticket Viewer, or with kinit.",
                responseTime: elapsed, serverVersion: nil, fix: .openTicketViewer)
        case .passwordRequired? where connection.authenticationMethod == .kerberos:
            result = ConnectionTestResult(isSuccessful: false, message: "The server asks for a password, not Kerberos.",
                                          responseTime: elapsed, serverVersion: nil, fix: .usePassword)
        case .clientCertificate(let file)? where file.kind == .wrongKeyPassword:
            result = ConnectionTestResult(isSuccessful: false, message: "Could not open the client key: the key password is wrong.",
                                          responseTime: elapsed, serverVersion: nil, keyPasswordIssue: "The key password is wrong.")
        case .clientCertificate(let file)? where file.kind == .keyNeedsPassword:
            result = ConnectionTestResult(isSuccessful: false, message: "The client key is protected by a password. Enter the key password.",
                                          responseTime: elapsed, serverVersion: nil, keyPasswordIssue: "Enter the password that protects the key.")
        default:
            break
        }
        return result
    }

    /// The server a connect would use: the first in order whose role fits Connect To.
    static func chosenIndex(_ roles: [PostgresHostProbe.Role?], for target: PostgresConnectTo) -> Int? {
        func first(_ role: PostgresHostProbe.Role) -> Int? { roles.firstIndex(of: role) }
        let reachable = roles.firstIndex { $0 != nil }
        switch target {
        case .any: return reachable
        case .primary, .readWrite: return first(.primary)
        case .standby, .readOnly: return first(.standby)
        case .preferStandby: return first(.standby) ?? reachable
        }
    }

    /// Short names for the result line: "db1" for db1.corp.example.com, the port added when two
    /// servers share a name, IP addresses in full.
    static func displayNames(_ hosts: [PostgresHost]) -> [String] {
        let short = hosts.map { host -> String in
            let isAddress = host.host.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" }
            return isAddress ? host.host : String(host.host.split(separator: ".").first ?? Substring(host.host))
        }
        return zip(hosts, short).map { host, name in
            short.filter { $0 == name }.count > 1 ? "\(name):\(host.port)" : name
        }
    }

    private static func reason(_ error: (any Error)?) -> String {
        guard let error else { return "failed" }
        return error.localizedDescription
    }
}

private extension PostgresConnectTo {
    /// "a primary", "a standby", for "No server is a primary".
    var wanted: String {
        switch self {
        case .any: "reachable"
        case .primary: "a primary"
        case .standby, .preferStandby: "a standby"
        case .readWrite: "writable"
        case .readOnly: "read-only"
        }
    }
}
