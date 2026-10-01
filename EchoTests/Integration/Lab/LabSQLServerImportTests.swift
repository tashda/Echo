import Foundation
import ServerLabClient
import SQLServerKit
import Testing
@testable import Echo

/// The Import Data sheet's SQL Server path (round 25) against a fresh lab server: the bulk load in
/// one transaction, its options, and what the sheet says afterwards.
@Suite(.enabled(if: labIntegrationEnabled, labIntegrationNote), .server("mssql-2022-empty"), .timeLimit(.minutes(10)))
@MainActor
struct LabSQLServerImportTests {
    private func connect() async throws -> SQLServerSessionAdapter {
        let server = try #require(LabServer.current)
        let session = try await MSSQLNIOFactory().connect(
            host: server.host, port: server.port, database: "master", tls: true, trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password),
            connectTimeoutSeconds: 30
        )
        return try #require(session as? SQLServerSessionAdapter)
    }

    private func makeViewModel(_ session: SQLServerSessionAdapter, table: String) -> BulkImportViewModel {
        let connectionSession = ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Import", database: "master", databaseType: .microsoftSQL),
            session: session,
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(
                rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("LabImport-\(UUID().uuidString)")))
        )
        return BulkImportViewModel(session: session, connectionSession: connectionSession, databaseType: .microsoftSQL,
                                   schema: "dbo", tableName: table)
    }

    /// Writes `csv`, maps its columns by name and runs the import to its end.
    private func runImport(_ viewModel: BulkImportViewModel, csv: String, configure: (BulkImportViewModel) -> Void = { _ in }) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        viewModel.fileURL = url
        await viewModel.parseFile()
        await viewModel.loadTargetColumns()
        configure(viewModel)
        viewModel.startImport()
        for _ in 0..<600 where viewModel.isImporting { try await Task.sleep(for: .milliseconds(100)) }
        #expect(!viewModel.isImporting, "The import did not finish within 60 seconds")
    }

    private func count(_ session: SQLServerSessionAdapter, _ table: String) async throws -> Int {
        try await session.client.query("SELECT COUNT(*) AS n FROM dbo.[\(table)]").first?.column("n")?.int ?? -1
    }

    @Test func importsInBatchesOfTenThousandRows() async throws {
        let session = try await connect()
        let table = "import_\(UUID().uuidString.prefix(8))"
        _ = try await session.client.execute("CREATE TABLE dbo.[\(table)] (id int NOT NULL PRIMARY KEY, name nvarchar(50), ordered date)")
        defer { Task { _ = try? await session.client.execute("DROP TABLE dbo.[\(table)]"); await session.close() } }

        let csv = "id,name,ordered\n" + (1...25_000).map { "\($0),Customer \($0),2024-02-29" }.joined(separator: "\n")
        let viewModel = makeViewModel(session, table: table)
        #expect(viewModel.batchSize == 10_000)
        try await runImport(viewModel, csv: csv)

        #expect(viewModel.phase == .completed(rowCount: 25_000, duration: viewModel.elapsedTime))
        #expect(viewModel.completedBatches == 3)
        #expect(viewModel.completionNote == nil, "The bulk load was used")
        #expect(try await count(session, table) == 25_000)
    }

    @Test func aFailureLeavesTheTableAsItWas() async throws {
        let session = try await connect()
        let table = "import_\(UUID().uuidString.prefix(8))"
        _ = try await session.client.execute("CREATE TABLE dbo.[\(table)] (id int NOT NULL PRIMARY KEY, ordered date)")
        defer { Task { _ = try? await session.client.execute("DROP TABLE dbo.[\(table)]"); await session.close() } }

        // Row 25,000 is not a date; batches 1 and 2 were already sent when the server refuses it.
        let csv = "id,ordered\n" + (1...30_000).map { "\($0),\($0 == 25_000 ? "not a date" : "2024-02-29")" }.joined(separator: "\n")
        let viewModel = makeViewModel(session, table: table)
        try await runImport(viewModel, csv: csv)

        guard case .failed(let message) = viewModel.phase else {
            Issue.record("Expected a failure, got \(viewModel.phase)"); return
        }
        #expect(message == "Nothing was imported. dbo.\(table) is as it was.")
        #expect(viewModel.failureDetail?.isEmpty == false)
        #expect(try await count(session, table) == 0, "The transaction rolled back the batches before the failure")
    }

    @Test func emptyCellsBecomeNullOrTheColumnDefault() async throws {
        let session = try await connect()
        let table = "import_\(UUID().uuidString.prefix(8))"
        _ = try await session.client.execute("CREATE TABLE dbo.[\(table)] (id int NOT NULL PRIMARY KEY, status nvarchar(20) NULL DEFAULT N'new')")
        defer { Task { _ = try? await session.client.execute("DROP TABLE dbo.[\(table)]"); await session.close() } }

        try await runImport(makeViewModel(session, table: table), csv: "id,status\n1,\n")
        try await runImport(makeViewModel(session, table: table), csv: "id,status\n2,\n") { $0.emptyCells = .columnDefault }
        let rows = try await session.client.query("SELECT id, status FROM dbo.[\(table)] ORDER BY id")
        #expect(rows.map { $0.column("status")?.string } == [nil, "new"])
    }
}
