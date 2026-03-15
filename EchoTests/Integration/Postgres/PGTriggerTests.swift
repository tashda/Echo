import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL trigger operations through Echo's DatabaseSession layer.
final class PGTriggerTests: PostgresDockerTestCase {

    // MARK: - BEFORE INSERT Trigger

    func testBeforeInsertTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let triggerName = uniqueName(prefix: "trg_bi")
        let funcName = uniqueName(prefix: "fn_bi")

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .timestamp(name: "created_at", defaultValue: nil)
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: """
                BEGIN
                    NEW.created_at := NOW();
                    RETURN NEW;
                END;
                """,
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await postgresClient.admin.createTrigger(
            name: triggerName,
            table: tableName,
            event: .before,
            operations: [.insert],
            procedure: "\(funcName)()"
        )

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Alice"]])

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

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createTable(name: logTable, columns: [
            .text(name: "op"),
            .text(name: "old_name"),
            .text(name: "new_name")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: """
                BEGIN
                    INSERT INTO \(logTable) (op, old_name, new_name)
                    VALUES ('UPDATE', OLD.name, NEW.name);
                    RETURN NEW;
                END;
                """,
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await postgresClient.admin.createTrigger(
            name: triggerName,
            table: tableName,
            event: .after,
            operations: [.update],
            procedure: "\(funcName)()"
        )

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Old"]])
        try await postgresClient.connection.update(table: tableName, set: ["name": "New"], whereClause: "name = 'Old'")

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

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createTable(name: logTable, columns: [
            .text(name: "op"),
            .text(name: "deleted_name")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: """
                BEGIN
                    INSERT INTO \(logTable) (op, deleted_name)
                    VALUES ('DELETE', OLD.name);
                    RETURN OLD;
                END;
                """,
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await postgresClient.admin.createTrigger(
            name: triggerName,
            table: tableName,
            event: .after,
            operations: [.delete],
            procedure: "\(funcName)()"
        )

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["ToDelete"]])
        try await postgresClient.connection.delete(from: tableName, whereClause: "name = 'ToDelete'")

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

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createTable(name: logTable, columns: [
            .text(name: "op")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(logTable) CASCADE"
        )

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: """
                BEGIN
                    INSERT INTO \(logTable) (op) VALUES ('INSERT');
                    RETURN NEW;
                END;
                """,
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await postgresClient.admin.createTrigger(
            name: triggerName,
            table: tableName,
            event: .after,
            operations: [.insert],
            procedure: "\(funcName)()"
        )

        // Disable trigger
        try await postgresClient.admin.alterTrigger(name: triggerName, table: tableName, enabled: false)
        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Disabled"]])
        let afterDisable = try await query("SELECT COUNT(*) FROM \(logTable)")
        XCTAssertEqual(afterDisable.rows[0][0], "0", "Trigger should not fire when disabled")

        // Re-enable trigger
        try await postgresClient.admin.alterTrigger(name: triggerName, table: tableName, enabled: true)
        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Enabled"]])
        let afterEnable = try await query("SELECT COUNT(*) FROM \(logTable)")
        XCTAssertEqual(afterEnable.rows[0][0], "1", "Trigger should fire when re-enabled")
    }

    // MARK: - Drop Trigger

    func testDropTrigger() async throws {
        let tableName = uniqueName(prefix: "trg_tbl")
        let triggerName = uniqueName(prefix: "trg_drop")
        let funcName = uniqueName(prefix: "fn_drop")

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName) CASCADE")

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: "BEGIN RETURN NEW; END;",
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        try await postgresClient.admin.createTrigger(
            name: triggerName,
            table: tableName,
            event: .before,
            operations: [.insert],
            procedure: "\(funcName)()"
        )

        try await postgresClient.admin.dropTrigger(name: triggerName, table: tableName)

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

        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .integer(name: "value")
        ])
        try await postgresClient.admin.createTable(name: auditTable, columns: [
            .serial(name: "audit_id", primaryKey: true),
            .text(name: "table_name"),
            .text(name: "operation"),
            .text(name: "old_data"),
            .text(name: "new_data"),
            .timestamp(name: "changed_at", defaultValue: "NOW()")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP TABLE IF EXISTS \(auditTable) CASCADE"
        )

        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [],
            returnType: "TRIGGER",
            body: """
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
                """,
            language: .plpgsql,
            orReplace: true
        )
        cleanupSQL("DROP FUNCTION IF EXISTS \(funcName)() CASCADE")

        for op in ["INSERT", "UPDATE", "DELETE"] {
            let trgName = uniqueName(prefix: "trg") + "_\(op.lowercased())"
            let operation: PostgresTriggerOperation = switch op {
            case "INSERT": .insert
            case "UPDATE": .update
            case "DELETE": .delete
            default: .insert
            }
            try await postgresClient.admin.createTrigger(
                name: trgName,
                table: tableName,
                event: .after,
                operations: [operation],
                procedure: "\(funcName)()"
            )
        }

        try await postgresClient.connection.insert(into: tableName, columns: ["name", "value"], values: [["Item1", 10]])
        try await postgresClient.connection.update(table: tableName, set: ["name": "Item1Updated"], whereClause: "name = 'Item1'")
        try await postgresClient.connection.delete(from: tableName, whereClause: "name = 'Item1Updated'")

        let result = try await query("SELECT operation FROM \(auditTable) ORDER BY audit_id")
        IntegrationTestHelpers.assertRowCount(result, expected: 3)
        XCTAssertEqual(result.rows[0][0], "INSERT")
        XCTAssertEqual(result.rows[1][0], "UPDATE")
        XCTAssertEqual(result.rows[2][0], "DELETE")
    }
}
