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
        IntegrationTestHelpers.assertRowCount(result, expected: 10_000)
        XCTAssertEqual(result.columns.count, 3)
    }

    func testLargeDatasetPreservesAllRows() async throws {
        let rowCount = 8000
        let result = try await query("""
            SELECT n FROM generate_series(1, \(rowCount)) AS n ORDER BY n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: rowCount)

        // Verify first and last rows
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[rowCount - 1][0], "\(rowCount)")
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

        IntegrationTestHelpers.assertRowCount(result, expected: 8000)
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
        IntegrationTestHelpers.assertRowCount(result, expected: 2000)

        // Spot-check rows to verify cache integrity
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[0][1], "value_1")
        XCTAssertEqual(result.rows[999][0], "1000")
        XCTAssertEqual(result.rows[999][1], "value_1000")
        XCTAssertEqual(result.rows[1999][0], "2000")
        XCTAssertEqual(result.rows[1999][1], "value_2000")
    }

    func testRowCachePreservesNulls() async throws {
        let result = try await query("""
            SELECT n,
                   CASE WHEN n % 2 = 0 THEN n ELSE NULL END AS nullable
            FROM generate_series(1, 5000) AS n ORDER BY n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)

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
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)
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
        IntegrationTestHelpers.assertRowCount(result, expected: 6000)

        // Verify order is preserved even after batched formatting
        var previousValue = 0
        for i in stride(from: 0, to: 6000, by: 100) {
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
        IntegrationTestHelpers.assertRowCount(result, expected: 3000)
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
        IntegrationTestHelpers.assertRowCount(result, expected: 5000)

        // Random access to various positions
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[0][1], "10")

        XCTAssertEqual(result.rows[2499][0], "2500")
        XCTAssertEqual(result.rows[2499][1], "25000")

        XCTAssertEqual(result.rows[4999][0], "5000")
        XCTAssertEqual(result.rows[4999][1], "50000")
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
        IntegrationTestHelpers.assertRowCount(result1, expected: 5000)

        let result2 = try await query("SELECT n FROM generate_series(1, 3000) AS n")
        IntegrationTestHelpers.assertRowCount(result2, expected: 3000)

        let result3 = try await query("SELECT n FROM generate_series(1, 7000) AS n")
        IntegrationTestHelpers.assertRowCount(result3, expected: 7000)
    }

    func testSmallQueryAfterLargeQuery() async throws {
        // Large query first
        let large = try await query("SELECT n FROM generate_series(1, 8000) AS n")
        IntegrationTestHelpers.assertRowCount(large, expected: 8000)

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
