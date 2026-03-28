import Foundation
import MySQLKit
import Observation

@Observable
final class MySQLDatabaseSecurityViewModel {
    enum Section: String, CaseIterable {
        case users = "Users"
        case roles = "Roles"
        case privileges = "Privileges"
        case advancedObjects = "Advanced Objects"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .users
    var isInitialized = false

    var users: [MySQLUserAccount] = []
    var selectedUserID: Set<String> = []
    var selectedUserGrants: [String] = []
    var selectedUserLimits: MySQLAccountLimits?
    var selectedUserAdministrativeRoles: [MySQLAdministrativeRole] = []
    var isLoadingUsers = false
    var isLoadingUserDetails = false

    var roles: [MySQLRoleDefinition] = []
    var selectedRoleID: Set<String> = []
    var roleAssignments: [MySQLRoleAssignment] = []
    var isLoadingRoles = false

    var privileges: [MySQLPrivilegeGrant] = []
    var selectedPrivilegeID: Set<String> = []
    var isLoadingPrivileges = false

    var availableObjectSchemas: [String] = []
    var advancedObjectSchemaFilter: String = ""
    var selectedAdvancedObjectSection: AdvancedObjectSection = .functions
    var routines: [MySQLRoutineInfo] = []
    var triggers: [MySQLTriggerInfo] = []
    var events: [MySQLEventInfo] = []
    var selectedRoutineID: Set<String> = []
    var selectedTriggerID: Set<String> = []
    var selectedEventID: Set<String> = []
    var selectedAdvancedObjectDefinition: AdvancedObjectDefinition?
    var isLoadingAdvancedObjects = false

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        panelState = state
    }

    func initialize() async {
        isInitialized = true
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let mysql = session as? MySQLSession else { return }
        switch selectedSection {
        case .users:
            await loadUsers(mysql: mysql)
        case .roles:
            await loadRoles(mysql: mysql)
        case .privileges:
            await loadPrivileges(mysql: mysql)
        case .advancedObjects:
            await loadProgrammableObjects(mysql: mysql)
        }
    }

    func loadSelectedUserDetails() async {
        guard
            let mysql = session as? MySQLSession,
            let account = selectedUser
        else {
            selectedUserGrants = []
            selectedUserLimits = nil
            selectedUserAdministrativeRoles = []
            return
        }

        isLoadingUserDetails = true
        defer { isLoadingUserDetails = false }

        do {
            let existingRoles = roles
            async let grants = mysql.client.security.showGrants(for: account.username, host: account.host)
            async let limits = mysql.client.security.accountLimits(for: account.username, host: account.host)
            async let roles = mysql.client.security.administrativeRoles(for: account.username, host: account.host)
            async let availableRoles = existingRoles.isEmpty ? mysql.client.security.listRoles() : existingRoles
            async let roleAssignmentsResult = mysql.client.security.listRoleAssignments()
            async let schemaPrivileges = mysql.client.security.schemaPrivileges()
            selectedUserGrants = try await grants
            selectedUserLimits = try await limits
            selectedUserAdministrativeRoles = try await roles
            self.roles = try await availableRoles
            roleAssignments = try await roleAssignmentsResult
            privileges = try await schemaPrivileges
        } catch {
            panelState?.appendMessage("Failed to load user details: \(error.localizedDescription)", severity: .error)
        }
    }

    func createUser(username: String, host: String, password: String?, plugin: String?) async {
        guard let mysql = session as? MySQLSession else { return }
        let handle = activityEngine?.begin("Creating user \(username)", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.security.createUser(
                username: username,
                host: host,
                password: password,
                authenticationPlugin: plugin
            )
            handle?.succeed()
            panelState?.appendMessage("Created user '\(username)'@'\(host)'")
            await loadUsers(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create user '\(username)'@'\(host)': \(error.localizedDescription)", severity: .error)
        }
    }

    func lockSelectedUser() async { await updateSelectedUser(locking: true) }
    func unlockSelectedUser() async { await updateSelectedUser(locking: false) }

    func dropSelectedUser() async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }
        let handle = activityEngine?.begin("Dropping user \(account.accountName)", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.security.dropUser(username: account.username, host: account.host)
            handle?.succeed()
            panelState?.appendMessage("Dropped user \(account.accountName)")
            selectedUserID.removeAll()
            await loadUsers(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop user \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    func createRole(name: String, host: String) async {
        guard let mysql = session as? MySQLSession else { return }
        let handle = activityEngine?.begin("Creating role \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mysql.client.security.createRole(name: name, host: host)
            handle?.succeed()
            panelState?.appendMessage("Created role '\(name)'@'\(host)'")
            await loadRoles(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to create role '\(name)'@'\(host)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropSelectedRole() async {
        guard let mysql = session as? MySQLSession, let role = selectedRole else { return }
        let handle = activityEngine?.begin("Dropping role \(role.accountName)", connectionSessionID: connectionSessionID)
        do {
            try await mysql.client.security.dropRole(name: role.name, host: role.host)
            handle?.succeed()
            panelState?.appendMessage("Dropped role \(role.accountName)")
            selectedRoleID.removeAll()
            await loadRoles(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop role \(role.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    var selectedUser: MySQLUserAccount? {
        users.first { selectedUserID.contains($0.id) }
    }

    var selectedRole: MySQLRoleDefinition? {
        roles.first { selectedRoleID.contains($0.id) }
    }

    var selectedRoleAssignments: [MySQLRoleAssignment] {
        guard let role = selectedRole else { return roleAssignments }
        return roleAssignments.filter { $0.roleName == role.name && $0.roleHost == role.host }
    }

    var selectedUserRoleAssignments: [MySQLRoleAssignment] {
        guard let user = selectedUser else { return [] }
        return roleAssignments.filter { $0.grantee == user.accountName }
    }

    var privilegeGrantees: [MySQLPrivilegeGrantee] {
        let userTargets = users.map {
            MySQLPrivilegeGrantee(kind: .user, username: $0.username, host: $0.host)
        }
        let roleTargets = roles.map {
            MySQLPrivilegeGrantee(kind: .role, username: $0.name, host: $0.host)
        }
        return (userTargets + roleTargets).sorted { $0.accountName < $1.accountName }
    }

    var selectedUserPrivileges: [MySQLPrivilegeGrant] {
        guard let user = selectedUser else { return [] }
        return privileges.filter {
            guard let grantee = $0.parsedGrantee else { return false }
            return grantee.username == user.username && grantee.host == user.host
        }
    }

    private func loadUsers(mysql: MySQLSession) async {
        isLoadingUsers = true
        defer { isLoadingUsers = false }
        do {
            users = try await mysql.client.security.listUsers()
            if selectedUser == nil {
                selectedUserID = users.first.map { [$0.id] } ?? []
            }
            await loadSelectedUserDetails()
        } catch {
            panelState?.appendMessage("Failed to load users: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadRoles(mysql: MySQLSession) async {
        isLoadingRoles = true
        defer { isLoadingRoles = false }
        do {
            async let rolesResult = mysql.client.security.listRoles()
            async let assignmentsResult = mysql.client.security.listRoleAssignments()
            roles = try await rolesResult
            roleAssignments = try await assignmentsResult
            if selectedRole == nil {
                selectedRoleID = roles.first.map { [$0.id] } ?? []
            }
        } catch {
            panelState?.appendMessage("Failed to load roles: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadPrivileges(mysql: MySQLSession) async {
        isLoadingPrivileges = true
        defer { isLoadingPrivileges = false }
        do {
            let existingUsers = users
            let existingRoles = roles
            async let schemaPrivileges = mysql.client.security.schemaPrivileges()
            async let usersResult = existingUsers.isEmpty ? mysql.client.security.listUsers() : existingUsers
            async let rolesResult = existingRoles.isEmpty ? mysql.client.security.listRoles() : existingRoles
            privileges = try await schemaPrivileges
            users = try await usersResult
            roles = try await rolesResult
        } catch {
            panelState?.appendMessage("Failed to load privileges: \(error.localizedDescription)", severity: .error)
        }
    }

    func grantSchemaPrivileges(
        on databaseName: String,
        to grantee: MySQLPrivilegeGrantee,
        privileges: [MySQLSchemaPrivilege],
        withGrantOption: Bool
    ) async {
        guard let mysql = session as? MySQLSession else { return }
        let handle = activityEngine?.begin("Granting privileges to \(grantee.accountName)", connectionSessionID: connectionSessionID)
        do {
            let privilegeList = privileges.map(\.rawValue).joined(separator: ", ")
            try await mysql.client.security.grant(
                privilegeList,
                on: "`\(databaseName.replacingOccurrences(of: "`", with: "``"))`.*",
                to: grantee.username,
                host: grantee.host,
                withGrantOption: withGrantOption
            )
            handle?.succeed()
            panelState?.appendMessage("Granted privileges to \(grantee.accountName) on \(databaseName)")
            await loadPrivileges(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to grant privileges to \(grantee.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    func revokePrivilege(_ privilege: MySQLPrivilegeGrant) async {
        guard
            let mysql = session as? MySQLSession,
            let grantee = privilege.parsedGrantee,
            let schema = privilege.tableSchema
        else { return }

        let handle = activityEngine?.begin("Revoking \(privilege.privilegeType)", connectionSessionID: connectionSessionID)
        do {
            let object = if let tableName = privilege.tableName, !tableName.isEmpty {
                "`\(schema.replacingOccurrences(of: "`", with: "``"))`.`\(tableName.replacingOccurrences(of: "`", with: "``"))`"
            } else {
                "`\(schema.replacingOccurrences(of: "`", with: "``"))`.*"
            }
            try await mysql.client.security.revoke(
                privilege.privilegeType,
                on: object,
                from: grantee.username,
                host: grantee.host
            )
            handle?.succeed()
            panelState?.appendMessage("Revoked \(privilege.privilegeType) from \(grantee.accountName)")
            await loadPrivileges(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to revoke privilege: \(error.localizedDescription)", severity: .error)
        }
    }

    func updateSelectedUserLimits(_ limits: MySQLAccountLimits) async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }
        let handle = activityEngine?.begin("Updating account limits", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.security.setAccountLimits(
                for: account.username,
                host: account.host,
                limits: limits
            )
            handle?.succeed()
            panelState?.appendMessage("Updated limits for \(account.accountName)")
            await loadSelectedUserDetails()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update limits for \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    func updateSelectedUserAdministrativeRoles(_ roles: Set<MySQLAdministrativeRole>) async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }
        let existingRoles = Set(selectedUserAdministrativeRoles)
        let rolesToGrant = roles.subtracting(existingRoles)
        let rolesToRevoke = existingRoles.subtracting(roles)
        guard !rolesToGrant.isEmpty || !rolesToRevoke.isEmpty else { return }

        let handle = activityEngine?.begin("Updating administrative roles", connectionSessionID: connectionSessionID)
        do {
            for role in rolesToGrant.sorted(by: { $0.rawValue < $1.rawValue }) {
                try await mysql.client.security.grantAdministrativeRole(role, to: account.username, host: account.host)
            }
            for role in rolesToRevoke.sorted(by: { $0.rawValue < $1.rawValue }) {
                try await mysql.client.security.revokeAdministrativeRole(role, from: account.username, host: account.host)
            }
            handle?.succeed()
            panelState?.appendMessage("Updated administrative roles for \(account.accountName)")
            await loadSelectedUserDetails()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update administrative roles for \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    func updateSelectedUserPassword(_ password: String) async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else { return }

        let handle = activityEngine?.begin("Updating password", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.security.alterUserPassword(
                username: account.username,
                host: account.host,
                password: trimmedPassword
            )
            handle?.succeed()
            panelState?.appendMessage("Updated password for \(account.accountName)")
            await loadSelectedUserDetails()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update password for \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    func updateSelectedUserRoleMembership(_ roleIDs: Set<String>) async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }

        let selectedRoles = roles.filter { roleIDs.contains($0.id) }
        let currentRoleIDs = Set(selectedUserRoleAssignments.map { "\($0.roleName)@\($0.roleHost)" })
        let nextRoleIDs = Set(selectedRoles.map(\.id))
        let rolesToGrant = selectedRoles.filter { !currentRoleIDs.contains($0.id) }
        let rolesToRevoke = selectedUserRoleAssignments.filter { !nextRoleIDs.contains("\($0.roleName)@\($0.roleHost)") }
        guard !rolesToGrant.isEmpty || !rolesToRevoke.isEmpty else { return }

        let handle = activityEngine?.begin("Updating role membership", connectionSessionID: connectionSessionID)
        do {
            for role in rolesToGrant.sorted(by: { $0.accountName < $1.accountName }) {
                try await mysql.client.security.grantRole(role.name, roleHost: role.host, to: account.username, host: account.host)
            }
            for assignment in rolesToRevoke.sorted(by: { $0.roleName < $1.roleName }) {
                try await mysql.client.security.revokeRole(assignment.roleName, roleHost: assignment.roleHost, from: account.username, host: account.host)
            }
            handle?.succeed()
            panelState?.appendMessage("Updated role membership for \(account.accountName)")
            await loadSelectedUserDetails()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update role membership for \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }

    private func updateSelectedUser(locking: Bool) async {
        guard let mysql = session as? MySQLSession, let account = selectedUser else { return }
        let verb = locking ? "Locking" : "Unlocking"
        let handle = activityEngine?.begin("\(verb) user \(account.accountName)", connectionSessionID: connectionSessionID)
        do {
            if locking {
                _ = try await mysql.client.security.lockUser(username: account.username, host: account.host)
            } else {
                _ = try await mysql.client.security.unlockUser(username: account.username, host: account.host)
            }
            handle?.succeed()
            panelState?.appendMessage("\(locking ? "Locked" : "Unlocked") user \(account.accountName)")
            await loadUsers(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to \(locking ? "lock" : "unlock") user \(account.accountName): \(error.localizedDescription)", severity: .error)
        }
    }
}
