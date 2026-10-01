import XCTest
import SQLServerKit
@testable import Echo

@MainActor
final class MSSQLIntegrationTests: XCTestCase {
    private struct MSSQLConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
        let useTLS: Bool
    }

    /// The lab server with the AdventureWorks samples, shared by the suites of the run.
    private func loadConfig() async throws -> MSSQLConfig {
        let server = try await LabSharedServers.serverForSuite(LabRecipes.sqlServerSamples)
        return MSSQLConfig(host: server.host, port: server.port, database: "master",
                           username: server.username, password: server.password, useTLS: false)
    }

    private func connect(config: MSSQLConfig) async throws -> DatabaseSession {
        let factory = MSSQLNIOFactory()
        return try await factory.connect(
            host: config.host,
            port: config.port,
            database: config.database,
            tls: config.useTLS,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: config.username,
                password: config.password
            )
        )
    }

    private func makeDedicatedQuerySession(
        config: MSSQLConfig,
        database: String
    ) async throws -> MSSQLDedicatedQuerySession {
        let metadataSession = try await connect(config: config) as! SQLServerSessionAdapter
        addTeardownBlock {
            await metadataSession.close()
        }

        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: config.host,
            port: config.port,
            database: database,
            tls: config.useTLS,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: config.username,
                password: config.password
            ),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(configuration: configuration)
        let querySession = MSSQLDedicatedQuerySession(
            connection: connection,
            configuration: configuration,
            metadataSession: metadataSession
        )
        addTeardownBlock {
            await querySession.close()
        }
        return querySession
    }

    // MARK: - Basic Connectivity

    func testSimpleQuerySelect1() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    // MARK: - Schema Discovery

    func testListDatabases() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
        XCTAssertTrue(databases.contains("master"))
    }

    func testListSchemas() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let schemas = try await session.listSchemas()
        XCTAssertTrue(schemas.contains("dbo"))
    }

    func testListTablesAndViews() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let objects = try await session.listTablesAndViews(schema: "dbo")
        XCTAssertNotNil(objects)
    }

    // MARK: - Table Structure

    func testGetTableStructureDetails() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        // A table in master, made and removed through sqlserver-nio.
        let admin = (session as! SQLServerSessionAdapter).client.admin
        let tableName = "echo_test_\(UUID().uuidString.prefix(8).lowercased())"
        try await admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        addTeardownBlock { try? await admin.dropTable(name: tableName, ifExists: true) }

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertEqual(details.columns.map(\.name), ["id", "name"])
    }

    func testDedicatedSessionCanQueryAdventureWorksEmployeeAndContinue() async throws {
        // Remove when it passes (an expected failure that does not happen fails the test).
        XCTExpectFailure("A query tab reads table structure from the default database: tashda/Echo#28")
        let config = try await loadConfig()
        let targetDatabase = "AdventureWorks"
        let session = try await makeDedicatedQuerySession(config: config, database: targetDatabase)

        let result = try await session.simpleQuery(
            "SELECT * FROM HumanResources.Employee",
            progressHandler: { _ in }
        )
        XCTAssertFalse(result.rows.isEmpty)
        XCTAssertTrue(result.columns.contains(where: { $0.name.caseInsensitiveCompare("BusinessEntityID") == .orderedSame }))

        let details = try await session.getTableStructureDetails(schema: "HumanResources", table: "Employee")
        XCTAssertFalse(details.columns.isEmpty)

        let followUp = try await session.simpleQuery("SELECT TOP 1 BusinessEntityID FROM HumanResources.Employee")
        XCTAssertEqual(followUp.columns.first?.name, "BusinessEntityID")
        XCTAssertEqual(followUp.rows.count, 1)
    }
}
