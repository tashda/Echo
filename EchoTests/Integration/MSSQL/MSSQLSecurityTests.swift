import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server security operations through Echo's DatabaseSession layer.
final class MSSQLSecurityTests: MSSQLDockerTestCase {

    // MARK: - Logins

    func testCreateAndDropLogin() async throws {
        let loginName = uniqueTableName(prefix: "login")
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        cleanupSQL("DROP LOGIN [\(loginName)]")

        let result = try await query("SELECT name FROM sys.sql_logins WHERE name = '\(loginName)'")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testDropLogin() async throws {
        let loginName = uniqueTableName(prefix: "login")
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")

        try await execute("DROP LOGIN [\(loginName)]")

        let result = try await query("SELECT name FROM sys.sql_logins WHERE name = '\(loginName)'")
        XCTAssertEqual(result.rows.count, 0)
    }

    // MARK: - Database Users

    func testCreateAndDropUser() async throws {
        let loginName = uniqueTableName(prefix: "login")
        let userName = uniqueTableName(prefix: "user")
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        cleanupSQL("DROP LOGIN [\(loginName)]")

        try await execute("CREATE USER [\(userName)] FOR LOGIN [\(loginName)]")
        cleanupSQL("DROP USER [\(userName)]")

        let result = try await query("SELECT name FROM sys.database_principals WHERE name = '\(userName)'")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - Roles

    func testCreateAndDropRole() async throws {
        let roleName = uniqueTableName(prefix: "role")
        try await execute("CREATE ROLE [\(roleName)]")
        cleanupSQL("DROP ROLE [\(roleName)]")

        let result = try await query("SELECT name FROM sys.database_principals WHERE name = '\(roleName)' AND type = 'R'")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testAddUserToRole() async throws {
        let loginName = uniqueTableName(prefix: "login")
        let userName = uniqueTableName(prefix: "user")
        let roleName = uniqueTableName(prefix: "role")
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        try await execute("CREATE USER [\(userName)] FOR LOGIN [\(loginName)]")
        try await execute("CREATE ROLE [\(roleName)]")
        cleanupSQL(
            "DROP USER [\(userName)]",
            "DROP ROLE [\(roleName)]",
            "DROP LOGIN [\(loginName)]"
        )

        try await execute("ALTER ROLE [\(roleName)] ADD MEMBER [\(userName)]")

        let result = try await query("""
            SELECT r.name AS role_name, m.name AS member_name
            FROM sys.database_role_members rm
            JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
            JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
            WHERE r.name = '\(roleName)'
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
    }

    // MARK: - Permissions

    func testGrantPermission() async throws {
        let loginName = uniqueTableName(prefix: "login")
        let userName = uniqueTableName(prefix: "user")
        let tableName = uniqueTableName()
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        try await execute("CREATE USER [\(userName)] FOR LOGIN [\(loginName)]")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL(
            "DROP TABLE [\(tableName)]",
            "DROP USER [\(userName)]",
            "DROP LOGIN [\(loginName)]"
        )

        try await execute("GRANT SELECT ON [\(tableName)] TO [\(userName)]")

        // Verify permission exists
        let result = try await query("""
            SELECT permission_name FROM sys.database_permissions
            WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID('\(userName)')
            AND permission_name = 'SELECT'
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
    }

    func testRevokePermission() async throws {
        let loginName = uniqueTableName(prefix: "login")
        let userName = uniqueTableName(prefix: "user")
        let tableName = uniqueTableName()
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        try await execute("CREATE USER [\(userName)] FOR LOGIN [\(loginName)]")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL(
            "DROP TABLE [\(tableName)]",
            "DROP USER [\(userName)]",
            "DROP LOGIN [\(loginName)]"
        )

        try await execute("GRANT SELECT ON [\(tableName)] TO [\(userName)]")
        try await execute("REVOKE SELECT ON [\(tableName)] FROM [\(userName)]")

        let result = try await query("""
            SELECT permission_name FROM sys.database_permissions
            WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID('\(userName)')
            AND major_id = OBJECT_ID('[\(tableName)]')
            AND permission_name = 'SELECT'
        """)
        XCTAssertEqual(result.rows.count, 0, "Permission should be revoked")
    }

    // MARK: - Schema Ownership

    func testCreateSchemaWithOwner() async throws {
        let loginName = uniqueTableName(prefix: "login")
        let userName = uniqueTableName(prefix: "user")
        let schemaName = uniqueTableName(prefix: "sch")
        try await execute("CREATE LOGIN [\(loginName)] WITH PASSWORD = 'StrongPass123!'")
        try await execute("CREATE USER [\(userName)] FOR LOGIN [\(loginName)]")
        cleanupSQL(
            "DROP SCHEMA [\(schemaName)]",
            "DROP USER [\(userName)]",
            "DROP LOGIN [\(loginName)]"
        )

        // Schema with AUTHORIZATION requires raw SQL — no typed API for owner
        try await execute("CREATE SCHEMA [\(schemaName)] AUTHORIZATION [\(userName)]")

        let schemas = try await session.listSchemas()
        IntegrationTestHelpers.assertContains(schemas, value: schemaName)
    }
}
