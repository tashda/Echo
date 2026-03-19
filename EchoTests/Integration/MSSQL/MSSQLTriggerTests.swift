import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server trigger operations through Echo's DatabaseSession layer.
final class MSSQLTriggerTests: MSSQLDockerTestCase {

    // MARK: - DML Triggers

    func testCreateInsertTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.admin.createTable(name: logTable, columns: [
            SQLServerColumnDefinition(name: "message", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
            SQLServerColumnDefinition(name: "logged_at", definition: .standard(.init(dataType: .datetime2(precision: 7), defaultValue: "GETDATE()"))),
        ])
        try await sqlserverClient.triggers.createTrigger(
            name: triggerName,
            table: tableName,
            timing: .after,
            events: [.insert],
            body: "INSERT INTO [\(logTable)] (message) VALUES ('Row inserted');"
        )
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Test")]
        )

        let result = try await query("SELECT message FROM [\(logTable)]")
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "Row inserted")
    }

    func testUpdateTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.admin.createTable(name: logTable, columns: [
            SQLServerColumnDefinition(name: "op", definition: .standard(.init(dataType: .nvarchar(length: .length(20))))),
        ])
        try await sqlserverClient.triggers.createTrigger(
            name: triggerName,
            table: tableName,
            timing: .after,
            events: [.update],
            body: "INSERT INTO [\(logTable)] VALUES ('UPDATE');"
        )
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Old")]
        )
        try await sqlserverClient.admin.updateRows(
            in: tableName,
            set: ["name": .nString("New")],
            where: "id = 1"
        )

        let result = try await query("SELECT op FROM [\(logTable)]")
        XCTAssertEqual(result.rows[0][0], "UPDATE")
    }

    func testDeleteTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.admin.createTable(name: logTable, columns: [
            SQLServerColumnDefinition(name: "op", definition: .standard(.init(dataType: .nvarchar(length: .length(20))))),
        ])
        try await sqlserverClient.triggers.createTrigger(
            name: triggerName,
            table: tableName,
            timing: .after,
            events: [.delete],
            body: "INSERT INTO [\(logTable)] VALUES ('DELETE');"
        )
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1)]
        )
        try await sqlserverClient.admin.deleteRows(
            from: tableName,
            where: "id = 1"
        )

        let result = try await query("SELECT op FROM [\(logTable)]")
        XCTAssertEqual(result.rows[0][0], "DELETE")
    }

    // MARK: - Enable/Disable Trigger

    func testDisableAndEnableTrigger() async throws {
        let tableName = uniqueTableName()
        let logTable = uniqueTableName(prefix: "log")
        let triggerName = uniqueTableName(prefix: "trg")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.admin.createTable(name: logTable, columns: [
            SQLServerColumnDefinition(name: "op", definition: .standard(.init(dataType: .nvarchar(length: .length(20))))),
        ])
        try await sqlserverClient.triggers.createTrigger(
            name: triggerName,
            table: tableName,
            timing: .after,
            events: [.insert],
            body: "INSERT INTO [\(logTable)] VALUES ('INSERT');"
        )
        cleanupSQL(
            "DROP TRIGGER [\(triggerName)]",
            "DROP TABLE [\(tableName)]",
            "DROP TABLE [\(logTable)]"
        )

        // Disable trigger
        try await sqlserverClient.triggers.disableTrigger(name: triggerName, table: tableName)
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1)]
        )
        let afterDisable = try await query("SELECT COUNT(*) FROM [\(logTable)]")
        XCTAssertEqual(afterDisable.rows[0][0], "0", "Trigger should not fire when disabled")

        // Re-enable trigger
        try await sqlserverClient.triggers.enableTrigger(name: triggerName, table: tableName)
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(2)]
        )
        let afterEnable = try await query("SELECT COUNT(*) FROM [\(logTable)]")
        XCTAssertEqual(afterEnable.rows[0][0], "1", "Trigger should fire when re-enabled")
    }

    // MARK: - Drop Trigger

    func testDropTrigger() async throws {
        let tableName = uniqueTableName()
        let triggerName = uniqueTableName(prefix: "trg")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.triggers.createTrigger(
            name: triggerName,
            table: tableName,
            timing: .after,
            events: [.insert],
            body: "SELECT 1;"
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.triggers.dropTrigger(name: triggerName)
        // Trigger should be gone — insert without error to verify
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1)]
        )
    }
}
