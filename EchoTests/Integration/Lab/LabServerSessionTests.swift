import Foundation
import ServerLabClient
import Testing
@testable import Echo

/// Echo's own sessions against fresh echo-server-lab servers. Run with SERVERLAB_INTEGRATION=1
/// (TEST_RUNNER_SERVERLAB_INTEGRATION=1 through xcodebuild).
private let labIntegrationEnabled = ProcessInfo.processInfo.environment["SERVERLAB_INTEGRATION"] == "1"

@Suite(.enabled(if: labIntegrationEnabled), .server("mssql-2022-column-types"))
@MainActor
struct LabSQLServerSessionTests {
    @Test func sessionListsEveryColumnTypeIncludingCLRTypes() async throws {
        let server = try #require(LabServer.current)
        let session = try await MSSQLNIOFactory().connect(
            host: server.host, port: server.port, database: "LabData", tls: true, trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password),
            connectTimeoutSeconds: 30
        )
        let columns = try await session.getTableSchema("AllTypes", schemaName: "dbo").map(\.name)
        await session.close()
        #expect(columns.count == 37)
        for clrColumn in ["HierarchyIdCol", "GeometryCol", "GeographyCol"] {
            #expect(columns.contains(clrColumn), "\(clrColumn) missing")
        }
    }
}

@Suite(.enabled(if: labIntegrationEnabled), .server("pg-17-column-types"))
@MainActor
struct LabPostgresSessionTests {
    @Test func sessionListsJsonAndEveryType() async throws {
        let server = try #require(LabServer.current)
        let session = try await PostgresNIOFactory().connect(
            host: server.host, port: server.port, database: "labdata", tls: false,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password),
            connectTimeoutSeconds: 30
        )
        let columns = try await session.getTableSchema("all_types", schemaName: "public")
        await session.close()
        #expect(columns.count == 52)
        #expect(columns.contains { $0.name == "jsonb_col" })
    }
}
