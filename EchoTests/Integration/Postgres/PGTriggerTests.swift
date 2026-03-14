import XCTest
@testable import Echo

/// Tests PostgreSQL trigger operations through Echo's DatabaseSession layer.
final class PGTriggerTests: PostgresDockerTestCase {

    // MARK: - BEFORE INSERT Trigger

    func testBeforeInsertTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let triggerName = uniqueName(prefix: "trg_bi")
        let funcName = uniqueName(prefix: "fn_bi")

        try await execute("""
            CREATE TABLE \(tableName) (
                id SERIAL PRIMARY KEY,
                name TEXT,
                created_at TIMESTAMP
            )
        """)
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.created_at := NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await execute("""
            CREATE TRIGGER \(triggerName)
            BEFORE INSERT ON \(tableName)
            FOR EACH ROW EXECUTE FUNCTION \(funcName)()
        """)

        try await execute("INSERT INTO \(tableName) (name) VALUES ('Alice')")

        let result = try await query("SELECT name, created_at FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "Alice")
        XCTAssertNotNil(result.rows[0][1], "created_at should be set by trigger")
    }

    // MARK: - AFTER UPDATE Trigger

    func testAfterUpdateTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let logTable = uniqueName(prefix: "trg_log")
        let triggerName = uniqueName(prefix: "trg_au")
        let funcName = uniqueName(prefix: "fn_au")

        try await execute("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE TABLE \(logTable) (op TEXT, old_name TEXT, new_name TEXT)")
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$
            BEGIN
                INSERT INTO \(logTable) (op, old_name, new_name)
                VALUES ('UPDATE', OLD.name, NEW.name);
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await execute("""
            CREATE TRIGGER \(triggerName)
            AFTER UPDATE ON \(tableName)
            FOR EACH ROW EXECUTE FUNCTION \(funcName)()
        """)

        try await execute("INSERT INTO \(tableName) (name) VALUES ('Old')")
        try await execute("UPDATE \(tableName) SET name = 'New' WHERE name = 'Old'")

        let result = try await query("SELECT op, old_name, new_name FROM \(logTable)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "UPDATE")
        XCTAssertEqual(result.rows[0][1], "Old")
        XCTAssertEqual(result.rows[0][2], "New")
    }

    // MARK: - AFTER DELETE Trigger

    func testAfterDeleteTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let logTable = uniqueName(prefix: "trg_log")
        let triggerName = uniqueName(prefix: "trg_ad")
        let funcName = uniqueName(prefix: "fn_ad")

        try await execute("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE TABLE \(logTable) (op TEXT, deleted_name TEXT)")
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$
            BEGIN
                INSERT INTO \(logTable) (op, deleted_name)
                VALUES ('DELETE', OLD.name);
                RETURN OLD;
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await execute("""
            CREATE TRIGGER \(triggerName)
            AFTER DELETE ON \(tableName)
            FOR EACH ROW EXECUTE FUNCTION \(funcName)()
        """)

        try await execute("INSERT INTO \(tableName) (name) VALUES ('ToDelete')")
        try await execute("DELETE FROM \(tableName) WHERE name = 'ToDelete'")

        let result = try await query("SELECT op, deleted_name FROM \(logTable)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "DELETE")
        XCTAssertEqual(result.rows[0][1], "ToDelete")
    }

    // MARK: - Enable/Disable Trigger

    func testDisableAndEnableTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let logTable = uniqueName(prefix: "trg_log")
        let triggerName = uniqueName(prefix: "trg_ed")
        let funcName = uniqueName(prefix: "fn_ed")

        try await execute("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE TABLE \(logTable) (op TEXT)")
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$
            BEGIN
                INSERT INTO \(logTable) (op) VALUES ('INSERT');
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await execute("""
            CREATE TRIGGER \(triggerName)
            AFTER INSERT ON \(tableName)
            FOR EACH ROW EXECUTE FUNCTION \(funcName)()
        """)

        // Disable trigger
        try await execute("ALTER TABLE \(tableName) DISABLE TRIGGER \(triggerName)")
        try await execute("INSERT INTO \(tableName) (name) VALUES ('Disabled')")
        let afterDisable = try await query("SELECT COUNT(*) FROM \(logTable)")
        XCTAssertEqual(afterDisable.rows[0][0], "0", "Trigger should not fire when disabled")

        // Re-enable trigger
        try await execute("ALTER TABLE \(tableName) ENABLE TRIGGER \(triggerName)")
        try await execute("INSERT INTO \(tableName) (name) VALUES ('Enabled')")
        let afterEnable = try await query("SELECT COUNT(*) FROM \(logTable)")
        XCTAssertEqual(afterEnable.rows[0][0], "1", "Trigger should fire when re-enabled")
    }

    // MARK: - Drop Trigger

    func testDropTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let triggerName = uniqueName(prefix: "trg_drop")
        let funcName = uniqueName(prefix: "fn_drop")

        try await execute("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY)")
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$ BEGIN RETURN NEW; END; $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await execute("""
            CREATE TRIGGER \(triggerName)
            BEFORE INSERT ON \(tableName)
            FOR EACH ROW EXECUTE FUNCTION \(funcName)()
        """)

        try await execute("DROP TRIGGER \(triggerName) ON \(tableName)")

        // Verify trigger is gone
        let result = try await query("""
            SELECT COUNT(*) FROM information_schema.triggers
            WHERE trigger_name = '\(triggerName)'
        """)
        XCTAssertEqual(result.rows[0][0], "0", "Trigger should be dropped")
    }

    // MARK: - Trigger with Audit Logging

    func testTriggerAuditLogging() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let auditTable = uniqueName(prefix: "trg_audit")
        let funcName = uniqueName(prefix: "fn_audit")

        try await execute("""
            CREATE TABLE \(tableName) (
                id SERIAL PRIMARY KEY,
                name TEXT,
                value INTEGER
            )
        """)
        try await execute("""
            CREATE TABLE \(auditTable) (
                audit_id SERIAL PRIMARY KEY,
                table_name TEXT,
                operation TEXT,
                old_data TEXT,
                new_data TEXT,
                changed_at TIMESTAMP DEFAULT NOW()
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(auditTable) CASCADE"
        )

        try await execute("""
            CREATE OR REPLACE FUNCTION \(funcName)()
            RETURNS TRIGGER AS $$
            BEGIN
                IF TG_OP = 'INSERT' THEN
                    INSERT INTO \(auditTable) (table_name, operation, new_data)
                    VALUES (TG_TABLE_NAME, 'INSERT', NEW.name);
                ELSIF TG_OP = 'UPDATE' THEN
                    INSERT INTO \(auditTable) (table_name, operation, old_data, new_data)
                    VALUES (TG_TABLE_NAME, 'UPDATE', OLD.name, NEW.name);
                ELSIF TG_OP = 'DELETE' THEN
                    INSERT INTO \(auditTable) (table_name, operation, old_data)
                    VALUES (TG_TABLE_NAME, 'DELETE', OLD.name);
                END IF;
                RETURN COALESCE(NEW, OLD);
            END;
            $$ LANGUAGE plpgsql
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        for op in ["INSERT", "UPDATE", "DELETE"] {
            try await execute("""
                CREATE TRIGGER \(uniqueName(prefix: "trg"))_\(op.lowercased())
                AFTER \(op) ON \(tableName)
                FOR EACH ROW EXECUTE FUNCTION \(funcName)()
            """)
        }

        try await execute("INSERT INTO \(tableName) (name, value) VALUES ('Item1', 10)")
        try await execute("UPDATE \(tableName) SET name = 'Item1Updated' WHERE name = 'Item1'")
        try await execute("DELETE FROM \(tableName) WHERE name = 'Item1Updated'")

        let result = try await query("SELECT operation FROM \(auditTable) ORDER BY audit_id")
        IntegrationTestHelpers.assertRowCount(result, expected: 3)
        XCTAssertEqual(result.rows[0][0], "INSERT")
        XCTAssertEqual(result.rows[1][0], "UPDATE")
        XCTAssertEqual(result.rows[2][0], "DELETE")
    }
}
