import XCTest
import SQLServerKit
@testable import Echo

/// SQL Server security through the echo-sqlserver APIs Echo's security screens use: logins, users,
/// roles, permissions and schema owners are made and read back with the typed clients.
final class MSSQLSecurityTests: MSSQLLabTestCase {
    private let loginPassword = "StrongPass123!"

    private var serverSecurity: SQLServerServerSecurityClient { sqlserverClient.serverSecurity }
    private var security: SQLServerSecurityClient { sqlserverClient.security }

    /// A login and a user for it in the suite's database.
    private func makeUser() async throws -> (login: String, user: String) {
        let login = uniqueTableName(prefix: "login")
        let user = uniqueTableName(prefix: "user")
        try await serverSecurity.createSqlLogin(name: login, password: loginPassword)
        try await security.createUser(name: user, login: login)
        return (login, user)
    }

    // MARK: - Logins

    func testCreateLogin() async throws {
        let loginName = uniqueTableName(prefix: "login")
        try await serverSecurity.createSqlLogin(name: loginName, password: loginPassword)

        let logins = try await serverSecurity.listLogins().map(\.name)
        XCTAssertTrue(logins.contains(loginName))
    }

    func testDropLogin() async throws {
        let loginName = uniqueTableName(prefix: "login")
        try await serverSecurity.createSqlLogin(name: loginName, password: loginPassword)

        try await serverSecurity.dropLogin(name: loginName)

        let logins = try await serverSecurity.listLogins().map(\.name)
        XCTAssertFalse(logins.contains(loginName))
    }

    // MARK: - Database Users

    func testCreateUser() async throws {
        let (_, user) = try await makeUser()

        let users = try await security.listUsers().map(\.name)
        XCTAssertTrue(users.contains(user))
    }

    // MARK: - Roles

    func testCreateRole() async throws {
        let roleName = uniqueTableName(prefix: "role")
        try await security.createRole(name: roleName)

        let roles = try await security.listRoles().map(\.name)
        XCTAssertTrue(roles.contains(roleName))
    }

    func testAddUserToRole() async throws {
        let (_, user) = try await makeUser()
        let roleName = uniqueTableName(prefix: "role")
        try await security.createRole(name: roleName)

        try await security.addUserToRole(user: user, role: roleName)

        let members = try await security.listRoleMembers(role: roleName)
        XCTAssertEqual(members, [user])
    }

    // MARK: - Permissions

    private func makeTableForPermissions() async throws -> SQLServerKit.ObjectIdentifier {
        let tableName = uniqueTableName()
        try await createTable(tableName, [.column("id", .int, primaryKey: true)])
        return SQLServerKit.ObjectIdentifier(schema: "dbo", name: tableName, kind: .table)
    }

    func testGrantPermission() async throws {
        let (_, user) = try await makeUser()
        let table = try await makeTableForPermissions()

        try await security.grant(permission: .select, on: .object(table), to: user)

        let permissions = try await security.listPermissions(principal: user)
        XCTAssertTrue(permissions.contains { $0.permission == "SELECT" && $0.state.hasPrefix("GRANT") && $0.objectName == table.name },
                      "\(permissions.map { "\($0.state) \($0.permission) \($0.objectName ?? "")" })")
    }

    func testRevokePermission() async throws {
        let (_, user) = try await makeUser()
        let table = try await makeTableForPermissions()
        try await security.grant(permission: .select, on: .object(table), to: user)

        try await security.revoke(permission: .select, on: .object(table), from: user)

        let permissions = try await security.listPermissions(principal: user)
        XCTAssertFalse(permissions.contains { $0.permission == "SELECT" && $0.objectName == table.name }, "Permission should be revoked")
    }

    // MARK: - Schema Ownership

    func testCreateSchemaWithOwner() async throws {
        let (_, user) = try await makeUser()
        let schemaName = uniqueTableName(prefix: "sch")

        try await security.createSchema(name: schemaName, authorization: user)

        let schemas = try await session.listSchemas()
        IntegrationTestHelpers.assertContains(schemas, value: schemaName)
    }
}
