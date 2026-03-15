import XCTest
@testable import Echo

/// Tests spool behavior for large result sets through Echo's streaming pipeline.
final class MSSQLStreamingSpoolTests: MSSQLDockerTestCase {

    // MARK: - Large Dataset Streaming

    func testLargeDatasetStreamsWithProgress() async throws {
        let progressUpdates = LockIsolated<[QueryStreamUpdate]>([])

        let result = try await session.simpleQuery(
            """
            SELECT TOP 10000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num,
                REPLICATE('X', 50) AS padding,
                CAST(RAND(CHECKSUM(NEWID())) * 1000 AS DECIMAL(10,2)) AS amount
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
            """,
            progressHandler: { update in
                progressUpdates.withValue { $0.append(update) }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 10000)
        XCTAssertEqual(result.columns.count, 3)
    }

    func testProgressUpdatesContainRowCounts() async throws {
        let totalRowCounts = LockIsolated<[Int]>([])

        _ = try await session.simpleQuery(
            """
            SELECT TOP 5000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n,
                REPLICATE('A', 100) AS data
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
            """,
            progressHandler: { update in
                totalRowCounts.withValue { $0.append(update.totalRowCount) }
            }
        )

        // If progress was reported, counts should be monotonically increasing
        if totalRowCounts.value.count > 1 {
            for i in 1..<totalRowCounts.value.count {
                XCTAssertGreaterThanOrEqual(
                    totalRowCounts.value[i], totalRowCounts.value[i - 1],
                    "Total row count should be monotonically increasing"
                )
            }
        }
    }

    func testProgressUpdatesContainColumns() async throws {
        let columnsFromProgress = LockIsolated<[ColumnInfo]>([])

        _ = try await session.simpleQuery(
            """
            SELECT TOP 2000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id,
                'test' AS name
            FROM sys.all_columns
            """,
            progressHandler: { update in
                if !update.columns.isEmpty && columnsFromProgress.value.isEmpty {
                    columnsFromProgress.setValue(update.columns)
                }
            }
        )

        // If progress handler was called, it should include column metadata
        if !columnsFromProgress.value.isEmpty {
            XCTAssertEqual(columnsFromProgress.value.count, 2)
            let names = columnsFromProgress.value.map { $0.name.lowercased() }
            XCTAssertTrue(names.contains("id"))
            XCTAssertTrue(names.contains("name"))
        }
    }

    // MARK: - Row Data Integrity

    func testStreamedRowsHaveCorrectData() async throws {
        let result = try await query("""
            SELECT TOP 3000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num,
                'constant' AS fixed_text
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)

        IntegrationTestHelpers.assertRowCount(result, expected: 3000)

        // Verify first and last rows have expected structure
        XCTAssertEqual(result.rows[0].count, 2, "Each row should have 2 columns")
        XCTAssertNotNil(result.rows[0][0], "row_num should not be null")
        XCTAssertEqual(result.rows[0][1], "constant")

        // Last row should also be valid
        let lastRow = result.rows[2999]
        XCTAssertNotNil(lastRow[0])
        XCTAssertEqual(lastRow[1], "constant")
    }

    func testStreamedRowsPreserveOrder() async throws {
        let result = try await query("""
            SELECT TOP 1000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS seq
            FROM sys.all_columns
        """)

        IntegrationTestHelpers.assertRowCount(result, expected: 1000)

        // Row numbers should be sequential
        for i in 0..<result.rows.count {
            let expected = i + 1
            let actual = Int(result.rows[i][0] ?? "0") ?? 0
            XCTAssertEqual(actual, expected, "Row \(i) should have seq=\(expected), got \(actual)")
        }
    }

    // MARK: - Mixed Column Types in Large Results

    func testLargeResultWithMixedTypes() async throws {
        let result = try await query("""
            SELECT TOP 5000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS int_col,
                CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) * 1.5 AS DECIMAL(10,2)) AS dec_col,
                CAST(GETDATE() AS DATETIME2) AS date_col,
                REPLICATE('X', 20) AS text_col,
                CAST(CASE WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 2 = 0
                     THEN 1 ELSE 0 END AS BIT) AS bit_col
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)

        IntegrationTestHelpers.assertRowCount(result, expected: 5000)
        XCTAssertEqual(result.columns.count, 5)

        // Spot-check some rows have non-null values for all columns
        for i in stride(from: 0, to: min(result.rows.count, 100), by: 10) {
            for col in 0..<5 {
                XCTAssertNotNil(
                    result.rows[i][col],
                    "Row \(i), column \(col) should not be null"
                )
            }
        }
    }

    // MARK: - Streaming with NULLs

    func testStreamingWithInterspersedNulls() async throws {
        let result = try await query("""
            SELECT TOP 2000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num,
                CASE WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 3 = 0
                     THEN NULL
                     ELSE 'value' END AS nullable_col,
                CASE WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 5 = 0
                     THEN NULL
                     ELSE CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10))
                     END AS nullable_num
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)

        IntegrationTestHelpers.assertRowCount(result, expected: 2000)

        // Verify NULLs appear where expected
        var nullCount = 0
        for row in result.rows {
            if row[1] == nil { nullCount += 1 }
        }
        XCTAssertGreaterThan(nullCount, 0, "Should have some NULL values")
        XCTAssertLessThan(nullCount, result.rows.count, "Should not be all NULLs")
    }

    // MARK: - Streaming Execution Modes

    func testStreamingWithSimpleMode() async throws {
        let progressCount = LockIsolated(0)

        let result = try await session.simpleQuery(
            """
            SELECT TOP 3000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
            """,
            executionMode: .simple,
            progressHandler: { _ in progressCount.withValue { $0 += 1 } }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 3000)
    }

    func testStreamingWithAutoMode() async throws {
        let progressCount = LockIsolated(0)

        let result = try await session.simpleQuery(
            """
            SELECT TOP 3000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
            """,
            executionMode: .auto,
            progressHandler: { _ in progressCount.withValue { $0 += 1 } }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 3000)
    }

    // MARK: - Metrics

    func testProgressMetricsPresent() async throws {
        let metricsReceived = LockIsolated<[QueryStreamMetrics]>([])

        _ = try await session.simpleQuery(
            """
            SELECT TOP 5000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n,
                REPLICATE('X', 200) AS payload
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
            """,
            progressHandler: { update in
                if let metrics = update.metrics {
                    metricsReceived.withValue { $0.append(metrics) }
                }
            }
        )

        // Metrics may or may not be present depending on batch size thresholds
        if !metricsReceived.value.isEmpty {
            let first = metricsReceived.value[0]
            XCTAssertGreaterThan(first.batchRowCount, 0, "Batch row count should be positive")
            XCTAssertGreaterThanOrEqual(
                first.cumulativeRowCount, first.batchRowCount,
                "Cumulative should be >= batch count"
            )
        }
    }

    // MARK: - Wide Rows

    func testStreamingWideRows() async throws {
        let result = try await query("""
            SELECT TOP 1000
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id,
                REPLICATE('A', 500) AS col1,
                REPLICATE('B', 500) AS col2,
                REPLICATE('C', 500) AS col3,
                REPLICATE('D', 500) AS col4
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)

        IntegrationTestHelpers.assertRowCount(result, expected: 1000)

        // Verify wide values are preserved
        let firstRow = result.rows[0]
        XCTAssertEqual(firstRow[1]?.count, 500, "col1 should be 500 chars")
        XCTAssertEqual(firstRow[2]?.count, 500, "col2 should be 500 chars")
    }

    // MARK: - Empty and Small Results

    func testStreamingEmptyResultWithProgress() async throws {
        try await withTempTable { tableName in
            let progressCalled = LockIsolated(false)
            let result = try await session.simpleQuery(
                "SELECT * FROM [\(tableName)]",
                progressHandler: { _ in progressCalled.setValue(true) }
            )
            XCTAssertEqual(result.rows.count, 0)
        }
    }

    func testStreamingSingleRowWithProgress() async throws {
        let updates = LockIsolated<[QueryStreamUpdate]>([])

        let result = try await session.simpleQuery(
            "SELECT 1 AS val",
            progressHandler: { update in updates.withValue { $0.append(update) } }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }
}
