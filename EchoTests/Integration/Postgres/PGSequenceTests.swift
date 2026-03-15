import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL sequence operations through Echo's DatabaseSession layer.
final class PGSequenceTests: PostgresDockerTestCase {

    // MARK: - Create Sequence

    func testCreateSequence() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], seqName)
    }

    func testCreateSequenceWithAllOptions() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(
            name: seqName,
            startWith: 10,
            incrementBy: 5,
            minValue: 1,
            maxValue: 1000,
            cache: 10
        )
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
        try await postgresClient.admin.createSequence(
            name: seqName,
            startWith: 100,
            incrementBy: -1,
            minValue: 1,
            maxValue: 100
        )
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let v1 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v1, 100)

        let v2 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v2, 99)
    }

    // MARK: - Nextval / Currval

    func testNextval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let v1 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v1, 1)

        let v2 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v2, 2)

        let v3 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v3, 3)
    }

    func testCurrval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 10)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        // Must call nextval before currval
        _ = try await postgresClient.admin.nextval(seqName)

        let current = try await postgresClient.admin.currval(seqName)
        XCTAssertEqual(current, 10)
    }

    func testCurrvalReflectsLatestNextval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await postgresClient.admin.nextval(seqName)
        _ = try await postgresClient.admin.nextval(seqName)
        _ = try await postgresClient.admin.nextval(seqName)

        let current = try await postgresClient.admin.currval(seqName)
        XCTAssertEqual(current, 3)
    }

    func testSetval() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        try await postgresClient.admin.setval(seqName, value: 50)

        let next = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(next, 51, "nextval after setval(50) should return 51")
    }

    func testSetvalWithIsCalled() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        // setval with is_called = false means nextval returns the set value
        try await postgresClient.admin.setval(seqName, value: 50, isCalled: false)

        let next = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(next, 50)
    }

    // MARK: - Alter Sequence

    func testAlterSequenceIncrementBy() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await postgresClient.admin.nextval(seqName) // 1

        try await execute("ALTER SEQUENCE \(seqName) INCREMENT BY 5")

        let v1 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v1, 6, "After INCREMENT BY 5, next value should be 1+5=6")

        let v2 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v2, 11, "Next value should be 6+5=11")
    }

    func testAlterSequenceRestart() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        _ = try await postgresClient.admin.nextval(seqName) // 1
        _ = try await postgresClient.admin.nextval(seqName) // 2

        try await execute("ALTER SEQUENCE \(seqName) RESTART WITH 100")

        let next = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(next, 100)
    }

    func testAlterSequenceMinMax() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 1)
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
        try await postgresClient.admin.createSequence(name: seqName)

        try await postgresClient.admin.dropSequence(name: seqName)

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0, "Sequence should be dropped")
    }

    func testDropSequenceIfExists() async throws {
        let seqName = uniqueName(prefix: "seq")
        // Should not throw even if sequence does not exist
        try await postgresClient.admin.dropSequence(name: seqName, ifExists: true)
    }

    func testDropSequenceCascade() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "INTEGER", nullable: false, primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createSequence(name: seqName)
        try await execute("ALTER SEQUENCE \(seqName) OWNED BY \(tableName).id")
        try await execute("ALTER TABLE \(tableName) ALTER COLUMN id SET DEFAULT nextval('\(seqName)')")

        // Drop with cascade should work
        try await postgresClient.admin.dropSequence(name: seqName, cascade: true)

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0)

        try? await postgresClient.admin.dropTable(name: tableName, ifExists: true)
    }

    // MARK: - Sequence with Cycle

    func testSequenceWithMinMaxValue() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(
            name: seqName,
            startWith: 1,
            incrementBy: 1,
            minValue: 1,
            maxValue: 5,
            cycle: true
        )
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        for expected in 1...5 {
            let val = try await postgresClient.admin.nextval(seqName)
            XCTAssertEqual(val, expected)
        }

        // Should cycle back to MINVALUE
        let cycled = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(cycled, 1, "Sequence should cycle back to 1")
    }

    func testSequenceWithCustomStartAndIncrement() async throws {
        let seqName = uniqueName(prefix: "seq")
        try await postgresClient.admin.createSequence(name: seqName, startWith: 100, incrementBy: 10)
        cleanupSQL("DROP SEQUENCE IF EXISTS \(seqName)")

        let v1 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v1, 100)

        let v2 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v2, 110)

        let v3 = try await postgresClient.admin.nextval(seqName)
        XCTAssertEqual(v3, 120)
    }

    // MARK: - Sequence Owned By Column

    func testSequenceOwnedByColumn() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "INTEGER", nullable: false, primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createSequence(name: seqName)
        try await execute("ALTER SEQUENCE \(seqName) OWNED BY \(tableName).id")
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await execute("ALTER TABLE \(tableName) ALTER COLUMN id SET DEFAULT nextval('\(seqName)')")

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["auto-id"]])
        let result = try await query("SELECT id, name FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNotNil(result.rows[0][0], "id should be auto-generated from sequence")
    }

    func testSequenceDroppedWithOwnerTable() async throws {
        let tableName = uniqueName(prefix: "seq_tbl")
        let seqName = uniqueName(prefix: "seq")

        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "INTEGER", nullable: false, primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createSequence(name: seqName)
        try await execute("ALTER SEQUENCE \(seqName) OWNED BY \(tableName).id")

        // Dropping the table should also drop the owned sequence
        try await postgresClient.admin.dropTable(name: tableName, cascade: true)

        let result = try await query("""
            SELECT sequencename FROM pg_sequences WHERE sequencename = '\(seqName)'
        """)
        XCTAssertEqual(result.rows.count, 0, "Owned sequence should be dropped with table")
    }

    // MARK: - Sequence in Schema

    func testSequenceInNonPublicSchema() async throws {
        let schemaName = uniqueName(prefix: "sch")
        let seqName = uniqueName(prefix: "seq")

        try await postgresClient.admin.createSchema(name: schemaName)
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        try await postgresClient.admin.createSequence(name: "\(schemaName).\(seqName)", startWith: 42)

        let result = try await query("SELECT nextval('\(schemaName).\(seqName)')")
        XCTAssertEqual(result.rows[0][0], "42")
    }
}
