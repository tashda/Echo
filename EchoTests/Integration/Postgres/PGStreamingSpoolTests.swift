import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL streaming spool activation and behavior for large result sets.
final class PGStreamingSpoolTests: PostgresDockerTestCase {

    // MARK: - Spool Activation for Large Datasets

    func testLargeDatasetCompletesSuccessfully() async throws {
        // A dataset large enough that the streaming pipeline processes it in batches
        let result = try await query("""
            SELECT n, md5(n::TEXT) AS hash, repeat('x', 100) AS padding
            FROM generate_series(1, 10000) AS n
        """)
        XCTAssertEqual(result.totalRowCount, 10_000, "Expected 10000 total rows")
        XCTAssertEqual(result.columns.count, 3)
    }

    func testLargeDatasetPreservesAllRows() async throws {
        let rowCount = 8000
        let result = try await query("""
            SELECT n FROM generate_series(1, \(rowCount)) AS n ORDER BY n
        """)
        XCTAssertEqual(result.totalRowCount, rowCount, "Expected \(rowCount) total rows")

        // Verify first row (streaming preview keeps first ~200 rows)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testLargeDatasetWithProgressHandler() async throws {
        let updateCount = LockIsolated(0)
        let lastTotalRowCount = LockIsolated(0)

        let result = try await session.simpleQuery(
            "SELECT n, repeat('data', 25) AS payload FROM generate_series(1, 8000) AS n",
            progressHandler: { update in
                updateCount.withValue { $0 += 1 }
                lastTotalRowCount.setValue(update.totalRowCount)
            }
        )

        XCTAssertEqual(result.totalRowCount, 8000, "Expected 8000 total rows")
        // With a large enough dataset, we should receive multiple progress updates
        // (exact count depends on batch size)
    }

    // MARK: - Row Cache Behavior

    func testRowCacheWithSmallResult() async throws {
        // Small results should be fully cached in memory
        let result = try await query("SELECT n FROM generate_series(1, 100) AS n ORDER BY n")
        IntegrationTestHelpers.assertRowCount(result, expected: 100)

        // All rows should be accessible
        for i in 0..<100 {
            XCTAssertEqual(result.rows[i][0], "\(i + 1)")
        }
    }

    func testRowCacheWithModerateResult() async throws {
        let result = try await query("""
            SELECT n, 'value_' || n AS label FROM generate_series(1, 2000) AS n ORDER BY n
        """)
        XCTAssertEqual(result.totalRowCount, 2000, "Expected 2000 total rows")

        // Spot-check rows within the preview window
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[0][1], "value_1")
        if result.rows.count > 99 {
            XCTAssertEqual(result.rows[99][0], "100")
            XCTAssertEqual(result.rows[99][1], "value_100")
        }
    }

    func testRowCachePreservesNulls() async throws {
        let result = try await query("""
            SELECT n,
                   CASE WHEN n % 2 = 0 THEN n ELSE NULL END AS nullable
            FROM generate_series(1, 5000) AS n ORDER BY n
        """)
        XCTAssertEqual(result.totalRowCount, 5000, "Expected 5000 total rows")

        // Odd rows should have NULL in second column
        XCTAssertNil(result.rows[0][1], "Row 1 (odd) should be NULL")
        XCTAssertEqual(result.rows[1][1], "2", "Row 2 (even) should have value")
        XCTAssertNil(result.rows[2][1], "Row 3 (odd) should be NULL")
        XCTAssertEqual(result.rows[3][1], "4", "Row 4 (even) should have value")
    }

    // MARK: - Deferred Formatting

    func testLargeResultWithMixedTypes() async throws {
        // This tests that deferred formatting handles various types correctly
        let result = try await query("""
            SELECT
                n::INTEGER AS int_col,
                (n * 1.5)::NUMERIC(12,2) AS numeric_col,
                ('2024-01-01'::DATE + (n || ' days')::INTERVAL)::DATE AS date_col,
                md5(n::TEXT) AS hash_col,
                n % 2 = 0 AS bool_col
            FROM generate_series(1, 5000) AS n
        """)
        XCTAssertEqual(result.totalRowCount, 5000, "Expected 5000 total rows")
        XCTAssertEqual(result.columns.count, 5)

        // Verify formatting is correct for first row
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertNotNil(result.rows[0][1]) // numeric
        XCTAssertNotNil(result.rows[0][2]) // date
        XCTAssertNotNil(result.rows[0][3]) // md5 hash
        XCTAssertNotNil(result.rows[0][4]) // boolean
    }

    func testDeferredFormattingPreservesOrder() async throws {
        let result = try await query("""
            SELECT n FROM generate_series(1, 6000) AS n ORDER BY n
        """)
        XCTAssertEqual(result.totalRowCount, 6000, "Expected 6000 total rows")

        // Verify order is preserved even after batched formatting
        var previousValue = 0
        for i in stride(from: 0, to: min(result.rows.count, 200), by: 10) {
            let value = Int(result.rows[i][0]!)!
            XCTAssertGreaterThan(value, previousValue, "Row ordering should be preserved at index \(i)")
            previousValue = value
        }
    }

    func testDeferredFormattingWithWideRows() async throws {
        // Wide rows (many columns, long strings) test deferred formatting under load
        let result = try await query("""
            SELECT
                n,
                repeat('a', 200) AS long_a,
                repeat('b', 200) AS long_b,
                repeat('c', 200) AS long_c,
                repeat('d', 200) AS long_d,
                repeat('e', 200) AS long_e
            FROM generate_series(1, 3000) AS n
        """)
        XCTAssertEqual(result.totalRowCount, 3000, "Expected 3000 total rows")
        XCTAssertEqual(result.columns.count, 6)

        // Verify wide row content
        XCTAssertEqual(result.rows[0][1]?.count, 200)
        XCTAssertEqual(result.rows[0][2]?.count, 200)
    }

    // MARK: - Materialization of Results

    func testMaterializationTotalRowCount() async throws {
        let result = try await query("""
            SELECT n FROM generate_series(1, 7000) AS n
        """)
        // totalRowCount should reflect the full result
        let total = result.totalRowCount ?? result.rows.count
        XCTAssertEqual(total, 7000)
    }

    func testMaterializationColumnInfo() async throws {
        let result = try await query("""
            SELECT n::INTEGER AS id, 'name_' || n AS name, n * 1.1 AS score
            FROM generate_series(1, 5000) AS n
        """)

        // Column metadata should be fully materialized
        XCTAssertEqual(result.columns.count, 3)
        IntegrationTestHelpers.assertHasColumn(result, named: "id")
        IntegrationTestHelpers.assertHasColumn(result, named: "name")
        IntegrationTestHelpers.assertHasColumn(result, named: "score")
    }

    func testMaterializationRandomAccess() async throws {
        let result = try await query("""
            SELECT n, n * 10 AS tens FROM generate_series(1, 5000) AS n ORDER BY n
        """)
        XCTAssertEqual(result.totalRowCount, 5000, "Expected 5000 total rows")

        // Verify rows within the preview window
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[0][1], "10")

        if result.rows.count > 99 {
            XCTAssertEqual(result.rows[99][0], "100")
            XCTAssertEqual(result.rows[99][1], "1000")
        }
    }

    func testMaterializationWithEmptyResult() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .integer(name: "value")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        let result = try await session.simpleQuery(
            "SELECT * FROM \(tableName)",
            progressHandler: { _ in }
        )

        XCTAssertEqual(result.rows.count, 0)
        let total = result.totalRowCount ?? 0
        XCTAssertEqual(total, 0)
    }

    // MARK: - Sequential Execution

    func testMultipleLargeQueriesSequential() async throws {
        // Ensure spool state is properly reset between queries
        let result1 = try await query("SELECT n FROM generate_series(1, 5000) AS n")
        XCTAssertEqual(result1.totalRowCount, 5000, "Expected 5000 total rows")

        let result2 = try await query("SELECT n FROM generate_series(1, 3000) AS n")
        XCTAssertEqual(result2.totalRowCount, 3000, "Expected 3000 total rows")

        let result3 = try await query("SELECT n FROM generate_series(1, 7000) AS n")
        XCTAssertEqual(result3.totalRowCount, 7000, "Expected 7000 total rows")
    }

    func testSmallQueryAfterLargeQuery() async throws {
        // Large query first
        let large = try await query("SELECT n FROM generate_series(1, 8000) AS n")
        XCTAssertEqual(large.totalRowCount, 8000, "Expected 8000 total rows")

        // Small query should work normally after
        let small = try await query("SELECT 1 AS val")
        IntegrationTestHelpers.assertRowCount(small, expected: 1)
        XCTAssertEqual(small.rows[0][0], "1")
    }

    // MARK: - Edge Cases

    func testSingleRowWithProgressHandler() async throws {
        let updateCount = LockIsolated(0)
        let result = try await session.simpleQuery(
            "SELECT 42 AS val",
            progressHandler: { _ in updateCount.withValue { $0 += 1 } }
        )

        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testVeryWideRowsSmallCount() async throws {
        // Few rows but very wide (large per-row data volume)
        let result = try await query("""
            SELECT n, repeat('x', 10000) AS big_col FROM generate_series(1, 50) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 50)
        XCTAssertEqual(result.rows[0][1]?.count, 10_000)
    }
}
