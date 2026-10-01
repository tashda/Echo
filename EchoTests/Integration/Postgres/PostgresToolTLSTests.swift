import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// #34: the bundled pg_dump reaches a TLS-only server the way the connection does, verifying the
/// server's certificate against the connection's CA, through the backup sheet's own path.
@MainActor
final class PostgresToolTLSTests: XCTestCase {
    private func viewModel(_ server: LabServer, tlsMode: TLSMode, caPath: String?) -> PostgresBackupRestoreViewModel {
        var connection = SavedConnection(
            connectionName: "TLS", host: server.host, port: server.port, database: "postgres",
            username: server.username, authenticationMethod: .sqlPassword, useTLS: tlsMode != .disable,
            databaseType: .postgresql
        )
        connection.tlsMode = tlsMode
        connection.sslRootCertPath = caPath
        return PostgresBackupRestoreViewModel(connection: connection, session: MockDatabaseSession(),
                                              databaseName: "postgres", password: server.password)
    }

    private func dumpSchema(_ viewModel: PostgresBackupRestoreViewModel) async throws -> ProcessResult {
        let pgDump = try XCTUnwrap(PostgresToolLocator.pgDumpURL())
        let tool = try await viewModel.toolConnection(database: "postgres")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("tls-\(UUID().uuidString).sql")
        defer { try? FileManager.default.removeItem(at: output) }
        let result = try await PostgresProcessRunner().run(
            executable: pgDump,
            arguments: ["--dbname", tool.connectionString, "--schema-only", "--file", output.path, "--no-password"],
            environment: tool.environment
        )
        withExtendedLifetime(tool) {}
        return result
    }

    func testBackupVerifiesTheServerWithTheConnectionsCA() async throws {
        let server = try await labServer("pg-17-tls-required")
        let ca = try XCTUnwrap(server.tls?.caPath)
        let result = try await dumpSchema(viewModel(server, tlsMode: .verifyFull, caPath: ca))
        XCTAssertEqual(result.exitCode, 0, result.stderrLines.joined(separator: "\n"))
    }

    func testBackupWithoutTLSIsRefusedByATLSOnlyServer() async throws {
        let server = try await labServer("pg-17-tls-required")
        let result = try await dumpSchema(viewModel(server, tlsMode: .disable, caPath: nil))
        XCTAssertNotEqual(result.exitCode, 0)
    }
}
