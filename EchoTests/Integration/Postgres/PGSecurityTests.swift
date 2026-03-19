import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL security operations (roles, permissions) through Echo's DatabaseSession layer.
final class PGSecurityTests: PostgresDockerTestCase {

    // MARK: - Create Role

    func testCreateRole() async throws {
        let roleName = uniqueName(prefix: "role")
        try await postgresClient.security.createRole(name: roleName)
        cleanupSQL("DROP ROLE IF EXISTS \(roleName)")

        let result = try await query("SELECT rolname FROM pg_roles WHERE rolname = '\(roleName)'")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], roleName)
    }

    // MARK: - Create Role with Password

    func testCreateRoleWithPassword() async throws {
        let roleName = uniqueName(prefix: "role")
        try await postgresClient.security.createRole(name: roleName, password: "TestPass123!", login: true)
        cleanupSQL("DROP ROLE IF EXISTS \(roleName)")

        let result = try await query("""
            SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname = '\(roleName)'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], roleName)
        XCTAssertEqual(result.rows[0][1], "t", "Role should have LOGIN privilege")
    }

    // MARK: - Grant SELECT on Table

    func testGrantSelectOnTable() async throws {
        let roleName = uniqueName(prefix: "role")
        let tableName = uniqueName(prefix: "sec_tbl")

        try await postgresClient.security.createRole(name: roleName)
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "data")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP ROLE IF EXISTS \(roleName)"
        )

        try await execute("GRANT SELECT ON \(tableName) TO \(roleName)")

        let result = try await query("""
            SELECT privilege_type FROM information_schema.role_table_grants
            WHERE grantee = '\(roleName)' AND table_name = '\(tableName)'
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
        let privileges = result.rows.compactMap { $0[0] }
        IntegrationTestHelpers.assertContains(privileges, value: "SELECT")
    }

    // MARK: - Revoke Permission

    func testRevokePermission() async throws {
        let roleName = uniqueName(prefix: "role")
        let tableName = uniqueName(prefix: "sec_tbl")

        try await postgresClient.security.createRole(name: roleName)
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP ROLE IF EXISTS \(roleName)"
        )

        try await execute("GRANT SELECT ON \(tableName) TO \(roleName)")
        try await execute("REVOKE SELECT ON \(tableName) FROM \(roleName)")

        let result = try await query("""
            SELECT privilege_type FROM information_schema.role_table_grants
            WHERE grantee = '\(roleName)' AND table_name = '\(tableName)'
            AND privilege_type = 'SELECT'
        """)
        XCTAssertEqual(result.rows.count, 0, "SELECT privilege should be revoked")
    }

    // MARK: - Add Role to Role (Role Membership)

    func testAddRoleToRole() async throws {
        let parentRole = uniqueName(prefix: "parent")
        let childRole = uniqueName(prefix: "child")

        try await postgresClient.security.createRole(name: parentRole)
        try await postgresClient.security.createRole(name: childRole)
        cleanupSQL(
            "REVOKE \(parentRole) FROM \(childRole)",
            "DROP ROLE IF EXISTS \(childRole)",
            "DROP ROLE IF EXISTS \(parentRole)"
        )

        try await execute("GRANT \(parentRole) TO \(childRole)")

        let result = try await query("""
            SELECT r.rolname AS member
            FROM pg_auth_members m
            JOIN pg_roles r ON m.member = r.oid
            JOIN pg_roles g ON m.roleid = g.oid
            WHERE g.rolname = '\(parentRole)'
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
        let members = result.rows.compactMap { $0[0] }
        IntegrationTestHelpers.assertContains(members, value: childRole)
    }

    // MARK: - Drop Role

    func testDropRole() async throws {
        let roleName = uniqueName(prefix: "role")
        try await postgresClient.security.createRole(name: roleName)

        try await postgresClient.security.dropRole(name: roleName)

        let result = try await query("SELECT rolname FROM pg_roles WHERE rolname = '\(roleName)'")
        XCTAssertEqual(result.rows.count, 0, "Role should be dropped")
    }

    // MARK: - Alter Role Attributes

    func testAlterRoleAttributes() async throws {
        let roleName = uniqueName(prefix: "role")
        try await postgresClient.security.createRole(name: roleName)
        cleanupSQL("DROP ROLE IF EXISTS \(roleName)")

        // Grant CREATEDB
        try await execute("ALTER ROLE \(roleName) CREATEDB")
        let r1 = try await query("SELECT rolcreatedb FROM pg_roles WHERE rolname = '\(roleName)'")
        XCTAssertEqual(r1.rows[0][0], "t", "Role should have CREATEDB")

        // Revoke CREATEDB
        try await execute("ALTER ROLE \(roleName) NOCREATEDB")
        let r2 = try await query("SELECT rolcreatedb FROM pg_roles WHERE rolname = '\(roleName)'")
        XCTAssertEqual(r2.rows[0][0], "f", "Role should not have CREATEDB")

        // Grant SUPERUSER (only works if connected as superuser)
        do {
            try await execute("ALTER ROLE \(roleName) SUPERUSER")
            let r3 = try await query("SELECT rolsuper FROM pg_roles WHERE rolname = '\(roleName)'")
            XCTAssertEqual(r3.rows[0][0], "t")
            // Clean up
            try await execute("ALTER ROLE \(roleName) NOSUPERUSER")
        } catch {
            // May fail if test user is not superuser — acceptable
        }
    }

    // MARK: - Grant Multiple Privileges

    func testGrantMultiplePrivileges() async throws {
        let roleName = uniqueName(prefix: "role")
        let tableName = uniqueName(prefix: "sec_tbl")

        try await postgresClient.security.createRole(name: roleName)
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "data")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS \(tableName) CASCADE",
            "DROP ROLE IF EXISTS \(roleName)"
        )

        try await execute("GRANT SELECT, INSERT, UPDATE ON \(tableName) TO \(roleName)")

        let result = try await query("""
            SELECT privilege_type FROM information_schema.role_table_grants
            WHERE grantee = '\(roleName)' AND table_name = '\(tableName)'
            ORDER BY privilege_type
        """)
        let privileges = result.rows.compactMap { $0[0] }
        IntegrationTestHelpers.assertContains(privileges, value: "SELECT")
        IntegrationTestHelpers.assertContains(privileges, value: "INSERT")
        IntegrationTestHelpers.assertContains(privileges, value: "UPDATE")
    }
}
