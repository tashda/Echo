import XCTest
import SQLServerKit
@testable import Echo

/// Round 22 BG1 against a real server: extra result sets of a SQL Server run stream into their own
/// results and spool like the first set, instead of holding every row in memory.
final class MSSQLDedicatedSessionResultSetTests: MSSQLLabTestCase {
    @MainActor
    private func makeDedicatedSession() async throws -> MSSQLDedicatedQuerySession {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: host,
            port: port,
            database: "master",
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: .init(method: .sqlPassword, username: username, password: password),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(configuration: configuration)
        let metadata = try XCTUnwrap(session as? SQLServerSessionAdapter)
        return MSSQLDedicatedQuerySession(connection: connection, configuration: configuration, metadataSession: metadata)
    }

    private static func numbers(_ count: Int, select: String) -> String {
        """
        WITH n AS (
            SELECT TOP (\(count)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        )
        SELECT \(select) FROM n ORDER BY i;
        """
    }

    @MainActor
    func testExtraResultSetsSpoolLikeTheFirst() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MSSQLDedicatedSessionResultSetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        // Same defaults as a real query tab.
        let state = QueryEditorState(sql: "", initialVisibleRowBatch: 500, previewRowLimit: 512,
                                     spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: tempRoot)))
        state.startExecution()
        let tabHandler: QueryProgressHandler = { [weak state] update in
            Task { @MainActor in state?.applyStreamUpdate(update) }
        }

        let sql = Self.numbers(3_000, select: "i, CAST(N'first' AS nvarchar(10)) AS t")
            + "\n"
            + Self.numbers(5_000, select: "i, CAST(i AS money) + 0.1234 AS m, CAST('2026-09-30 12:34:56.1234567' AS datetime2(7)) AS d")
        let result = try await dedicated.simpleQuery(sql, progressHandler: tabHandler)
        state.consumeFinalResult(result)
        state.finishExecution()

        let second = try XCTUnwrap(result.additionalResults.first)
        XCTAssertEqual(second.totalRowCount, 5_000)
        XCTAssertEqual(second.rows.count, 200, "Only the preview of an extra set stays in memory")

        let secondState = try XCTUnwrap(state.additionalResultState(at: 0))
        for _ in 0..<400 where state.displayedRowCount < 3_000 || secondState.displayedRowCount < 5_000 {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(state.displayedRowCount, 3_000)
        XCTAssertEqual(secondState.displayedRowCount, 5_000)
        for i in [1, 200, 201, 5_000] {
            XCTAssertEqual(secondState.displayedRow(at: i - 1), ["\(i)", "\(i).1234", "2026-09-30 12:34:56.1234567"], "row \(i) of the second set")
        }
        XCTAssertEqual(state.displayedRow(at: 2_999), ["3000", "first"])
    }
}
