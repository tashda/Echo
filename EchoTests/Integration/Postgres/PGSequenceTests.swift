import XCTest
@testable import Echo

/// Tests PostgreSQL sequence operations through Echo's DatabaseSession layer.
final class PGSequenceTests: PostgresDockerTestCase {

    // MARK: - Create Sequence

    func testCreateSequence() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName)")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], seqName)
    }

    func testCreateSequenceWithAllOptions() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("""
            CREATE SEQUENCE \(seqName)
            START 10 INCREMENT BY 5 MINVALUE 1 MAXVALUE 1000 CACHE 10
        """)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let result = try await query("""
            SELECT start_value, increment_by, min_value, max_value, cache_size
            FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "10")
        XCTAssertEqual(result.rows[0][1], "5")
        XCTAssertEqual(result.rows[0][2], "1")
        XCTAssertEqual(result.rows[0][3], "1000")
        XCTAssertEqual(result.rows[0][4], "10")
    }

    func testCreateDescendingSequence() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("""
            CREATE SEQUENCE \(seqName)
            START 100 INCREMENT BY -1 MINVALUE 1 MAXVALUE 100
        """)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let r1 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r1.rows[0][0], "100")

        let r2 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r2.rows[0][0], "99")
    }

    // MARK: - Nextval / Currval

    func testNextval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let r1 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r1.rows[0][0], "1")

        let r2 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r2.rows[0][0], "2")

        let r3 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r3.rows[0][0], "3")
    }

    func testCurrval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 10")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        // Must call nextval before currval
        _ = try await query("SELECT nextval('\(seqName)')")

        let result = try await query("SELECT currval('\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "10")
    }

    func testCurrvalReflectsLatestNextval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await query("SELECT nextval('\(seqName)')")
        _ = try await query("SELECT nextval('\(seqName)')")
        _ = try await query("SELECT nextval('\(seqName)')")

        let result = try await query("SELECT currval('\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "3")
    }

    func testSetval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await query("SELECT setval('\(seqName)', 50)")

        let result = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "51", "nextval after setval(50) should return 51")
    }

    func testSetvalWithIsCalled() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        // setval with is_called = false means nextval returns the set value
        _ = try await query("SELECT setval('\(seqName)', 50, false)")

        let result = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "50")
    }

    // MARK: - Alter Sequence

    func testAlterSequenceIncrementBy() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await query("SELECT nextval('\(seqName)')") // 1

        try await execute("ALTER SEQUENCE \(seqName) INCREMENT BY 5")

        let r1 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r1.rows[0][0], "6", "After INCREMENT BY 5, next value should be 1+5=6")

        let r2 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r2.rows[0][0], "11", "Next value should be 6+5=11")
    }

    func testAlterSequenceRestart() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await query("SELECT nextval('\(seqName)')") // 1
        _ = try await query("SELECT nextval('\(seqName)')") // 2

        try await execute("ALTER SEQUENCE \(seqName) RESTART WITH 100")

        let result = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "100")
    }

    func testAlterSequenceMinMax() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 1")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        try await execute("ALTER SEQUENCE \(seqName) MINVALUE 0 MAXVALUE 500")

        let result = try await query("""
            SELECT min_value, max_value FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows[0][0], "0")
        XCTAssertEqual(result.rows[0][1], "500")
    }

    // MARK: - Drop Sequence

    func testDropSequence() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName)")

        try await execute("DROP SEQUENCE \(seqName)")

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0, "Sequence should be dropped")
    }

    func testDropSequenceIfExists() async throws {
        let seqName = uniqueName(prefix: "seq")
        // Should not throw even if sequence does not exist
        try await execute("DROP SEQUENCE IF EXISTS \(seqName)")
    }

    func testDropSequenceCascade() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await execute("CREATE TABLE \(tableName) (id INTEGER PRIMARY KEY, name TEXT)")
        try await execute("CREATE SEQUENCE \(seqName) OWNED BY \(tableName).id")
        try await execute("ALTER TABLE \(tableName) ALTER COLUMN id SET DEFAULT nextval('\(seqName)')")

        // Drop with cascade should work
        try await execute("DROP SEQUENCE \(seqName) CASCADE")

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0)

        try? await execute("DROP TABLE IF EXISTS \(tableName)")
    }

    // MARK: - Sequence with Cycle

    func testSequenceWithMinMaxValue() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("""
            CREATE SEQUENCE \(seqName)
            START 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 5 CYCLE
        """)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        for expected in 1...5 {
            let result = try await query("SELECT nextval('\(seqName)')")
            XCTAssertEqual(result.rows[0][0], "\(expected)")
        }

        // Should cycle back to MINVALUE
        let cycled = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(cycled.rows[0][0], "1", "Sequence should cycle back to 1")
    }

    func testSequenceWithCustomStartAndIncrement() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await execute("CREATE SEQUENCE \(seqName) START 100 INCREMENT BY 10")
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let r1 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r1.rows[0][0], "100")

        let r2 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r2.rows[0][0], "110")

        let r3 = try await query("SELECT nextval('\(seqName)')")
        XCTAssertEqual(r3.rows[0][0], "120")
    }

    // MARK: - Sequence Owned By Column

    func testSequenceOwnedByColumn() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await execute("CREATE TABLE \(tableName) (id INTEGER PRIMARY KEY, name TEXT)")
        try await execute("CREATE SEQUENCE \(seqName) OWNED BY \(tableName).id")
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await execute("""
            ALTER TABLE \(tableName) ALTER COLUMN id SET DEFAULT nextval('\(seqName)')
        """)

        try await execute("INSERT INTO \(tableName) (name) VALUES ('auto-id')")
        let result = try await query("SELECT id, name FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNotNil(result.rows[0][0], "id should be auto-generated from sequence")
    }

    func testSequenceDroppedWithOwnerTable() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await execute("CREATE TABLE \(tableName) (id INTEGER PRIMARY KEY, name TEXT)")
        try await execute("CREATE SEQUENCE \(seqName) OWNED BY \(tableName).id")

        // Dropping the table should also drop the owned sequence
        try await execute("DROP TABLE \(tableName) CASCADE")

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0, "Owned sequence should be dropped with table")
    }

    // MARK: - Sequence in Schema

    func testSequenceInNonPublicSchema() async throws {
        let schemaName = uniqueName(prefix: "sch")
        let seqName = uniqueName(prefix: "seq")

        try await execute("CREATE SCHEMA \(schemaName)")
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        try await execute("CREATE SEQUENCE \(schemaName).\(seqName) START 42")

        let result = try await query("SELECT nextval('\(schemaName).\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "42")
    }
}
