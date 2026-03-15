import XCTest
@testable import Echo

/// Tests SQL Server trigger operations through Echo's DatabaseSession layer.
final class MSSQLTriggerTests: MSSQLDockerTestCase {

    // MARK: - DML Triggers

    func testCreateInsertTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE TABLE [\(logTable)] (message NVARCHAR(200), logged_at DATETIME2 DEFAULT GETDATE())")
        try await execute("""
            CREATE TRIGGER [\(triggerName)] ON [\(tableName)]
            AFTER INSERT
            AS
            BEGIN
                INSERT INTO [\(logTable)] (message) VALUES ('Row inserted');
            END
        """)
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Test')")

        let result = try await query("SELECT message FROM [\(logTable)]")
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "Row inserted")
    }

    func testUpdateTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE TABLE [\(logTable)] (op NVARCHAR(20))")
        try await execute("""
            CREATE TRIGGER [\(triggerName)] ON [\(tableName)]
            AFTER UPDATE
            AS BEGIN INSERT INTO [\(logTable)] VALUES ('UPDATE'); END
        """)
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Old')")
        try await execute("UPDATE [\(tableName)] SET name = 'New' WHERE id = 1")

        let result = try await query("SELECT op FROM [\(logTable)]")
        XCTAssertEqual(result.rows[0][0], "UPDATE")
    }

    func testDeleteTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY)")
        try await execute("CREATE TABLE [\(logTable)] (op NVARCHAR(20))")
        try await execute("""
            CREATE TRIGGER [\(triggerName)] ON [\(tableName)]
            AFTER DELETE
            AS BEGIN INSERT INTO [\(logTable)] VALUES ('DELETE'); END
        """)
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await execute("INSERT INTO [\(tableName)] VALUES (1)")
        try await execute("DELETE FROM [\(tableName)] WHERE id = 1")

        let result = try await query("SELECT op FROM [\(logTable)]")
        XCTAssertEqual(result.rows[0][0], "DELETE")
    }

    // MARK: - Enable/Disable Trigger

    func testDisableAndEnableTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY)")
        try await execute("CREATE TABLE [\(logTable)] (op NVARCHAR(20))")
        try await execute("""
            CREATE TRIGGER [\(triggerName)] ON [\(tableName)]
            AFTER INSERT
            AS BEGIN INSERT INTO [\(logTable)] VALUES ('INSERT'); END
        """)
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        // Disable trigger
        try await execute("DISABLE TRIGGER [\(triggerName)] ON [\(tableName)]")
        try await execute("INSERT INTO [\(tableName)] VALUES (1)")
        let afterDisable = try await query("SELECT COUNT(*) FROM [\(logTable)]")
        XCTAssertEqual(afterDisable.rows[0][0], "0", "Trigger should not fire when disabled")

        // Re-enable trigger
        try await execute("ENABLE TRIGGER [\(triggerName)] ON [\(tableName)]")
        try await execute("INSERT INTO [\(tableName)] VALUES (2)")
        let afterEnable = try await query("SELECT COUNT(*) FROM [\(logTable)]")
        XCTAssertEqual(afterEnable.rows[0][0], "1", "Trigger should fire when re-enabled")
    }

    // MARK: - Drop Trigger

    func testDropTrigger() async throws {
        let tableName = uniqueTableName()
        let triggerName = uniqueTableName(prefix: "trg")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY)")
        try await execute("""
            CREATE TRIGGER [\(triggerName)] ON [\(tableName)]
            AFTER INSERT AS BEGIN SELECT 1; END
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("DROP TRIGGER [\(triggerName)]")
        // Trigger should be gone — no way to directly verify without sys tables,
        // but we can insert without error
        try await execute("INSERT INTO [\(tableName)] VALUES (1)")
    }
}
