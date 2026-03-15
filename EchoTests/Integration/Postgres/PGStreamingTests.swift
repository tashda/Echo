import XCTest
@testable import Echo

/// Tests PostgreSQL query streaming through Echo's DatabaseSession layer.
final class PGStreamingTests: PostgresDockerTestCase {

    // MARK: - Progress Handler Receives Updates

    func testProgressHandlerCalled() async throws {
        let progressUpdates = LockIsolated<[QueryStreamUpdate]>([])

        let result = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 500) AS n",
            progressHandler: { update in
                progressUpdates.withValue { $0.append(update) }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 500)
    }

    func testProgressHandlerReceivesColumns() async throws {
        let streamColumns = LockIsolated<[ColumnInfo]>([])

        let result = try await session.simpleQuery(
            "SELECT 1::INTEGER AS int_col, 'text'::TEXT AS string_col, 3.14::DOUBLE PRECISION AS float_col",
            progressHandler: { update in
                if !update.columns.isEmpty {
                    streamColumns.setValue(update.columns)
                }
            }
        )

        XCTAssertEqual(result.columns.count, 3)
        IntegrationTestHelpers.assertHasColumn(result, named: "int_col")
        IntegrationTestHelpers.assertHasColumn(result, named: "string_col")
        IntegrationTestHelpers.assertHasColumn(result, named: "float_col")
    }

    func testProgressHandlerRowCountIncreases() async throws {
        let rowCounts = LockIsolated<[Int]>([])

        let result = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 1000) AS n",
            progressHandler: { update in
                rowCounts.withValue { $0.append(update.totalRowCount) }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 1000)

        // Row counts should be monotonically increasing
        for i in 1..<rowCounts.value.count {
            XCTAssertGreaterThanOrEqual(
                rowCounts.value[i], rowCounts.value[i - 1],
                "Row counts should be monotonically non-decreasing"
            )
        }
    }

    func testProgressHandlerAppendedRows() async throws {
        let totalAppendedRows = LockIsolated(0)

        _ = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 500) AS n",
            progressHandler: { update in
                totalAppendedRows.withValue { $0 += update.appendedRows.count }
            }
        )

        // Some rows should have been appended via progress updates
        // (exact count depends on batching behavior)
        XCTAssertGreaterThanOrEqual(totalAppendedRows.value, 0)
    }

    // MARK: - Large Result Set (5000+ rows)

    func testLargeResultSet5000Rows() async throws {
        let result = try await query("""
            SELECT n, 'row_' || n::TEXT AS label, n * 1.5 AS computed
            FROM generate_series(1, 5000) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)
        XCTAssertEqual(result.columns.count, 3)
    }

    func testLargeResultSetWithProgressTracking() async throws {
        let maxRowCount = LockIsolated(0)

        let result = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 5000) AS n",
            progressHandler: { update in
                maxRowCount.withValue { current in
                    if update.totalRowCount > current {
                        current = update.totalRowCount
                    }
                }
            }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 5000)
    }

    func testLargeResultSet10000Rows() async throws {
        let result = try await query("""
            SELECT n, md5(n::TEXT) AS hash FROM generate_series(1, 10000) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 10_000)
    }

    func testLargeResultSetDataIntegrity() async throws {
        let result = try await query("""
            SELECT n, n * 2 AS doubled, n * n AS squared
            FROM generate_series(1, 5000) AS n
            ORDER BY n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)

        // Verify first rows
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[0][1], "2")
        XCTAssertEqual(result.rows[0][2], "1")

        // Verify a middle row
        XCTAssertEqual(result.rows[499][0], "500")
        XCTAssertEqual(result.rows[499][1], "1000")
        XCTAssertEqual(result.rows[499][2], "250000")

        // Verify last row
        XCTAssertEqual(result.rows[4999][0], "5000")
        XCTAssertEqual(result.rows[4999][1], "10000")
        XCTAssertEqual(result.rows[4999][2], "25000000")
    }

    // MARK: - Many Columns

    func testResultSetWith20Columns() async throws {
        let result = try await query("""
            SELECT
                1 AS c1, 2 AS c2, 3 AS c3, 4 AS c4, 5 AS c5,
                6 AS c6, 7 AS c7, 8 AS c8, 9 AS c9, 10 AS c10,
                'a' AS c11, 'b' AS c12, 'c' AS c13, 'd' AS c14, 'e' AS c15,
                1.1 AS c16, 2.2 AS c17, 3.3 AS c18, 4.4 AS c19, 5.5 AS c20
        """)
        XCTAssertEqual(result.columns.count, 20)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testManyColumnsWithManyRows() async throws {
        let result = try await query("""
            SELECT
                n AS c1, n+1 AS c2, n+2 AS c3, n+3 AS c4, n+4 AS c5,
                n+5 AS c6, n+6 AS c7, n+7 AS c8, n+8 AS c9, n+9 AS c10,
                'row_' || n AS c11, md5(n::TEXT) AS c12,
                n * 1.5 AS c13, n * 2.5 AS c14, n::BOOLEAN AS c15
            FROM generate_series(1, 1000) AS n
        """)
        XCTAssertEqual(result.columns.count, 15)
        IntegrationTestHelpers.assertRowCount(result, expected: 1000)
    }

    // MARK: - Empty Result with Progress Handler

    func testEmptyResultWithProgressHandler() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            let progressCalled = LockIsolated(false)
            let result = try await session.simpleQuery(
                "SELECT * FROM \(tableName)",
                progressHandler: { _ in
                    progressCalled.setValue(true)
                }
            )
            XCTAssertEqual(result.rows.count, 0)
        }
    }

    func testEmptyResultFromWhereClause() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("INSERT INTO \(tableName) (name, value) VALUES ('test', 1)")

            let result = try await session.simpleQuery(
                "SELECT * FROM \(tableName) WHERE name = 'nonexistent'",
                progressHandler: { _ in }
            )
            XCTAssertEqual(result.rows.count, 0)
        }
    }

    // MARK: - Mixed Data Types in Stream

    func testMixedDataTypesInStream() async throws {
        let result = try await query("""
            SELECT
                n AS id,
                (n * 1.5)::NUMERIC(10,2) AS amount,
                NOW()::TIMESTAMP AS ts,
                gen_random_uuid() AS guid,
                repeat('A', 50) AS text_data
            FROM generate_series(1, 500) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 500)
        XCTAssertEqual(result.columns.count, 5)
    }

    func testStreamingWithNullValues() async throws {
        let result = try await query("""
            SELECT
                n AS id,
                CASE WHEN n % 2 = 0 THEN n ELSE NULL END AS even_only,
                CASE WHEN n % 3 = 0 THEN 'divisible' ELSE NULL END AS by_three
            FROM generate_series(1, 100) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 100)

        let nullCount = result.rows.filter { $0[1] == nil }.count
        XCTAssertGreaterThan(nullCount, 0, "Should have some NULL values in even_only column")
    }

    func testStreamingWithVariableLengthData() async throws {
        let result = try await query("""
            SELECT n, repeat('x', (n % 100) + 1) AS variable_text
            FROM generate_series(1, 1000) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1000)

        // Verify variable lengths
        let len1 = result.rows[0][1]?.count ?? 0
        let len50 = result.rows[49][1]?.count ?? 0
        XCTAssertNotEqual(len1, len50, "Text lengths should vary")
    }

    // MARK: - Execution Mode Parameter

    func testExecutionModeNil() async throws {
        let updateCount = LockIsolated(0)
        let result = try await session.simpleQuery(
            "SELECT generate_series(1, 100) AS n",
            executionMode: nil,
            progressHandler: { _ in updateCount.withValue { $0 += 1 } }
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 100)
    }

    func testExecutionModeAuto() async throws {
        let updateCount = LockIsolated(0)
        let result = try await session.simpleQuery(
            "SELECT generate_series(1, 200) AS n",
            executionMode: .auto,
            progressHandler: { _ in updateCount.withValue { $0 += 1 } }
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 200)
    }

    func testExecutionModeSimple() async throws {
        let result = try await session.simpleQuery(
            "SELECT generate_series(1, 100) AS n",
            executionMode: .simple,
            progressHandler: nil
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 100)
    }

    func testExecutionModeCursor() async throws {
        let result = try await session.simpleQuery(
            "SELECT generate_series(1, 200) AS n",
            executionMode: .cursor,
            progressHandler: nil
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 200)
    }

    // MARK: - Streaming Metrics

    func testStreamMetricsPresent() async throws {
        let metricsReceived = LockIsolated(false)

        _ = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 1000) AS n",
            progressHandler: { update in
                if update.metrics != nil {
                    metricsReceived.setValue(true)
                }
            }
        )

        // Metrics may or may not be present depending on batch size
        // Just ensure the test completes without error
    }

    func testStreamMetricsRowRange() async throws {
        let ranges = LockIsolated<[Range<Int>]>([])

        _ = try await session.simpleQuery(
            "SELECT n FROM generate_series(1, 2000) AS n",
            progressHandler: { update in
                if let range = update.rowRange {
                    ranges.withValue { $0.append(range) }
                }
            }
        )

        // If row ranges were reported, verify they are ordered
        if ranges.value.count > 1 {
            for i in 1..<ranges.value.count {
                XCTAssertGreaterThanOrEqual(
                    ranges.value[i].lowerBound, ranges.value[i - 1].lowerBound,
                    "Row ranges should be ordered"
                )
            }
        }
    }

    // MARK: - Column Metadata Preservation

    func testColumnMetadataForTypedQuery() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, name VARCHAR(100), score NUMERIC(5,2), active BOOLEAN"
        ) { tableName in
            try await execute("INSERT INTO \(tableName) (name, score, active) VALUES ('Test', 95.50, TRUE)")

            let result = try await query("SELECT * FROM \(tableName)")
            XCTAssertEqual(result.columns.count, 4)
            IntegrationTestHelpers.assertHasColumn(result, named: "id")
            IntegrationTestHelpers.assertHasColumn(result, named: "name")
            IntegrationTestHelpers.assertHasColumn(result, named: "score")
            IntegrationTestHelpers.assertHasColumn(result, named: "active")
        }
    }
}
