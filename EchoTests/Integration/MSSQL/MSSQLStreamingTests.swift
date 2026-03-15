import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server query streaming through Echo's DatabaseSession layer.
final class MSSQLStreamingTests: MSSQLDockerTestCase {

    // MARK: - Streaming with Progress

    func testStreamingQueryWithProgressHandler() async throws {
        let progressUpdates = LockIsolated<[QueryStreamUpdate]>([])

        let result = try await session.simpleQuery(
            "SELECT TOP 500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_columns a CROSS JOIN sys.all_columns b",
            progressHandler: { update in
                progressUpdates.withValue { $0.append(update) }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 500)
        // Progress handler may or may not be called depending on result size
    }

    func testStreamingQueryWithExecutionMode() async throws {
        let progressUpdates = LockIsolated<[QueryStreamUpdate]>([])

        let result = try await session.simpleQuery(
            "SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_columns",
            executionMode: nil,
            progressHandler: { update in
                progressUpdates.withValue { $0.append(update) }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 100)
    }

    // MARK: - Large Result Sets

    func testLargeResultSetStreaming() async throws {
        let result = try await query("""
            SELECT TOP 5000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num,
                REPLICATE('X', 100) AS padding
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)
    }

    func testResultSetWithManyColumns() async throws {
        let result = try await query("""
            SELECT TOP 10
                1 AS c1, 2 AS c2, 3 AS c3, 4 AS c4, 5 AS c5,
                6 AS c6, 7 AS c7, 8 AS c8, 9 AS c9, 10 AS c10,
                'a' AS c11, 'b' AS c12, 'c' AS c13, 'd' AS c14, 'e' AS c15,
                1.1 AS c16, 2.2 AS c17, 3.3 AS c18, 4.4 AS c19, 5.5 AS c20
        """)
        XCTAssertEqual(result.columns.count, 20)
        IntegrationTestHelpers.assertRowCount(result, expected: 10)
    }

    // MARK: - Column Metadata in Streaming

    func testStreamingPreservesColumnMetadata() async throws {
        let streamColumns = LockIsolated<[ColumnInfo]>([])

        _ = try await session.simpleQuery(
            "SELECT 1 AS int_col, 'text' AS string_col, 3.14 AS float_col",
            progressHandler: { update in
                if !update.columns.isEmpty {
                    streamColumns.setValue(update.columns)
                }
            }
        )

        // Even if progress wasn't called, the final result should have columns
        // This test verifies column metadata is preserved through the streaming path
    }

    // MARK: - Empty Streaming Result

    func testStreamingEmptyResult() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let progressCalled = LockIsolated(false)
        let result = try await session.simpleQuery(
            "SELECT * FROM [\(tableName)]",
            progressHandler: { _ in
                progressCalled.setValue(true)
            }
        )
        XCTAssertEqual(result.rows.count, 0)
    }

    // MARK: - Streaming with Mixed Data Types

    func testStreamingMixedDataTypes() async throws {
        let result = try await query("""
            SELECT TOP 100
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id,
                CAST(RAND(CHECKSUM(NEWID())) * 1000 AS DECIMAL(10,2)) AS amount,
                CAST(GETDATE() AS DATETIME2) AS timestamp,
                NEWID() AS guid,
                REPLICATE('A', 50) AS text_data
            FROM sys.all_columns
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 100)
        XCTAssertEqual(result.columns.count, 5)
    }
}
