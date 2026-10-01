import Testing
import Foundation
@testable import Echo

/// pg_dump, pg_restore and psql connect as the connection does (#34): its TLS mode and CA,
/// Kerberos encryption only for Kerberos sign-ins, and the password never on the command line.
@MainActor
@Suite("PostgresBackupRestoreViewModel - tool connection")
struct PostgresBackupEnvironmentTests {
    private func viewModel(
        authenticationMethod: DatabaseAuthenticationMethod,
        password: String? = "secret",
        change: (inout SavedConnection) -> Void = { _ in }
    ) -> PostgresBackupRestoreViewModel {
        var connection = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user",
            authenticationMethod: authenticationMethod,
            useTLS: false,
            databaseType: .postgresql
        )
        change(&connection)
        return PostgresBackupRestoreViewModel(
            connection: connection, session: MockDatabaseSession(),
            databaseName: "db", password: password
        )
    }

    @Test func passwordSignInKeepsThePasswordOffTheCommandLine() async throws {
        let tool = try await viewModel(authenticationMethod: .sqlPassword).toolConnection(database: "other")
        #expect(tool.environment == ["PGPASSWORD": "secret"])
        #expect(!tool.connectionString.contains("secret"))
        #expect(tool.connectionString.contains("dbname='other'"))
        #expect(tool.connectionString.contains("gssencmode='disable'"))
    }

    @Test func kerberosSignInPrefersGSSEncryption() async throws {
        let tool = try await viewModel(authenticationMethod: .kerberos, password: nil).toolConnection(database: "db")
        #expect(tool.environment.isEmpty)
        #expect(tool.connectionString.contains("gssencmode='prefer'"))
    }

    @Test func toolsGetTheConnectionsTLSSettings() async throws {
        let tool = try await viewModel(authenticationMethod: .sqlPassword) {
            $0.tlsMode = .verifyFull
            $0.sslRootCertPath = "/certs/ca.pem"
        }.toolConnection(database: "db")
        #expect(tool.connectionString.contains("sslmode='verify-full'"))
        #expect(tool.connectionString.contains("sslrootcert='/certs/ca.pem'"))
    }

    /// #43: the tools' forked workers can't use Apple's Kerberos, so a Kerberos sign-in runs one job.
    @Test func kerberosSignInRunsOneJob() {
        #expect(viewModel(authenticationMethod: .kerberos, password: nil).effectiveJobs(4, category: "Backup") == 1)
        #expect(viewModel(authenticationMethod: .sqlPassword).effectiveJobs(4, category: "Backup") == 4)
        #expect(viewModel(authenticationMethod: .kerberos, password: nil).effectiveJobs(1, category: "Backup") == 1)
    }
}
