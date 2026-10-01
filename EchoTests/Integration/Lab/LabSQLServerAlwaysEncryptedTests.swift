import Foundation
import ServerLabClient
import SQLServerKit
import Testing
@testable import Echo

/// Round 29 against the lab's EncryptedLab.dbo.Patients (SSN deterministic, Salary randomized):
/// Echo's SQL Server sessions describe the encrypted columns, streamed or not.
@Suite(.enabled(if: labIntegrationEnabled, labIntegrationNote), .server("mssql-2022-encryption"))
@MainActor
struct LabSQLServerAlwaysEncryptedTests {
    @Test func encryptedColumnsAreDescribedInEveryResultPath() async throws {
        let server = try #require(LabServer.current)
        let session = try #require(try await MSSQLNIOFactory().connect(
            host: server.host, port: server.port, database: "EncryptedLab", tls: true, trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password),
            connectTimeoutSeconds: 30
        ) as? SQLServerSessionAdapter)
        defer { Task { await session.close() } }

        // A row of ciphertext (nobody has the lab's key), copied in by a user allowed to.
        let login = "echo_ae_\(UUID().uuidString.prefix(8).lowercased())"
        let password = "Ae_\(UUID().uuidString)_a1"
        try await session.client.serverSecurity.createSqlLogin(name: login, password: password)
        defer { Task { try? await session.client.serverSecurity.dropLogin(name: login, dropMappedUsers: true) } }
        try await session.client.security.createUser(name: login, login: login, options: UserOptions(allowEncryptedValueModifications: true))
        try await session.client.security.addUserToRole(user: login, role: "db_owner")
        let copier = try await SQLServerConnection.connect(configuration: .init(
            hostname: server.host, port: server.port,
            login: .init(database: "EncryptedLab", authentication: .sqlPassword(username: login, password: password)),
            tlsConfiguration: .trustingServerCertificate
        ))
        var options = SQLServerBulkCopyOptions(table: "Patients", columns: ["Id", "SSN", "Salary"])
        options.allowEncryptedValueModifications = true
        let ciphertext: (Int) -> [UInt8] = { blocks in [0x01] + [UInt8](repeating: 0xAB, count: 32 + 16 + blocks * 16) }
        _ = try await copier.bulkCopy(rows: [SQLServerBulkCopyRow(values: [.int(900), .bytes(ciphertext(2)), .bytes(ciphertext(1))])], options: options)
        try? await copier.close()

        let sql = "SELECT Id, SSN, Salary FROM dbo.Patients WHERE Id = 900"
        let plain = try await session.simpleQuery(sql)                                   // Table Data's path
        let streamed = try await session.simpleQuery(sql, progressHandler: { _ in })     // the query grid's path
        for result in [plain, streamed] {
            #expect(result.columns.map(\.name) == ["Id", "SSN", "Salary"])
            #expect(result.columns[0].encryption == nil)
            #expect(result.columns[1].encryption?.typeName == "nvarchar(11)")
            #expect(result.columns[1].encryption?.kind == "deterministic")
            #expect(result.columns[2].encryption?.typeName == "int")
            #expect(result.columns[2].encryption?.kind == "randomized")
            #expect(ResultGridValueClassifier.kind(for: result.columns[1], value: result.rows.first?[1] ?? nil) == .encrypted)
            #expect(result.rows.first?[1]?.hasPrefix("0x01AB") == true, "The value is the ciphertext, which Copy gives")
        }
    }
}
