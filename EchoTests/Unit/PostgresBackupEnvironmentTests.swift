import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("PostgresBackupRestoreViewModel - tool environment")
struct PostgresBackupEnvironmentTests {
    private func viewModel(
        authenticationMethod: DatabaseAuthenticationMethod,
        useTLS: Bool = true,
        password: String? = "secret"
    ) -> PostgresBackupRestoreViewModel {
        let connection = SavedConnection(
            connectionName: "Test", host: "localhost", port: 5432,
            database: "db", username: "user",
            authenticationMethod: authenticationMethod,
            useTLS: useTLS,
            databaseType: .postgresql
        )
        return PostgresBackupRestoreViewModel(
            connection: connection, session: MockDatabaseSession(),
            databaseName: "db", password: password
        )
    }

    @Test func passwordSignInDisablesGSSEncryption() {
        let env = viewModel(authenticationMethod: .sqlPassword).buildEnvironment()
        #expect(env["PGGSSENCMODE"] == "disable")
        #expect(env["PGPASSWORD"] == "secret")
    }

    @Test func kerberosSignInPrefersGSSEncryption() {
        let env = viewModel(authenticationMethod: .kerberos, password: nil).buildEnvironment()
        #expect(env["PGGSSENCMODE"] == "prefer")
        #expect(env["PGPASSWORD"] == nil)
    }

    @Test func toolsGetNoDynamicLibraryPaths() {
        let env = viewModel(authenticationMethod: .sqlPassword).buildEnvironment()
        #expect(env["DYLD_LIBRARY_PATH"] == nil)
        #expect(env["DYLD_FALLBACK_LIBRARY_PATH"] == nil)
    }

    @Test func tlsSettingSetsSSLMode() {
        #expect(viewModel(authenticationMethod: .sqlPassword, useTLS: true).buildEnvironment()["PGSSLMODE"] == "require")
        #expect(viewModel(authenticationMethod: .sqlPassword, useTLS: false).buildEnvironment()["PGSSLMODE"] == "disable")
    }
}
