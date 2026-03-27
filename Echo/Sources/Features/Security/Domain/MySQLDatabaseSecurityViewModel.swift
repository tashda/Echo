import Foundation
import MySQLKit
import Observation

@Observable
final class MySQLDatabaseSecurityViewModel {
    enum Section: String, CaseIterable {
        case users = "Users"
        case roles = "Roles"
        case privileges = "Privileges"
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
            async let grants = mysql.client.security.showGrants(for: account.username, host: account.host)
            async let limits = mysql.client.security.accountLimits(for: account.username, host: account.host)
            async let roles = mysql.client.security.administrativeRoles(for: account.username, host: account.host)
            selectedUserGrants = try await grants
            selectedUserLimits = try await limits
            selectedUserAdministrativeRoles = try await roles
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
            privileges = try await mysql.client.security.tablePrivileges()
        } catch {
            panelState?.appendMessage("Failed to load privileges: \(error.localizedDescription)", severity: .error)
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
