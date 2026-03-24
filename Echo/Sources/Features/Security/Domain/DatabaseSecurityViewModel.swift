import Foundation
import Observation
import SQLServerKit

@Observable
final class DatabaseSecurityViewModel {

    enum Section: String, CaseIterable {
        case users = "Users"
        case roles = "Roles"
        case appRoles = "App Roles"
        case schemas = "Schemas"
        case masking = "Masking"
        case securityPolicies = "RLS"
        case auditSpecifications = "Audit Specs"
        case alwaysEncrypted = "Encryption"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .users
    var selectedDatabase: String?
    var databaseList: [String] = []
    var isInitialized = false

    // Users
    var users: [UserInfo] = []
    var selectedUserName: Set<String> = []
    var isLoadingUsers = false

    // Roles
    var roles: [RoleInfo] = []
    var selectedRoleName: Set<String> = []
    var isLoadingRoles = false

    // App Roles
    var appRoles: [ApplicationRoleInfo] = []
    var selectedAppRoleName: Set<String> = []
    var isLoadingAppRoles = false

    // Schemas
    var schemas: [SQLServerKit.SchemaInfo] = []
    var selectedSchemaName: Set<String> = []
    var isLoadingSchemas = false

    // Dynamic Data Masking
    var maskedColumns: [MaskedColumnInfo] = []
    var selectedMaskedColumnID: Set<String> = []
    var isLoadingMaskedColumns = false

    // Row-Level Security
    var securityPolicies: [SecurityPolicyInfo] = []
    var selectedPolicyID: Set<String> = []
    var isLoadingSecurityPolicies = false

    // Database Audit Specifications
    var dbAuditSpecs: [AuditSpecificationInfo] = []
    var selectedDBAuditSpecName: Set<String> = []
    var isLoadingDBAuditSpecs = false

    // Always Encrypted
    var columnMasterKeys: [ColumnMasterKeyInfo] = []
    var columnEncryptionKeys: [ColumnEncryptionKeyInfo] = []
    var selectedCMKName: Set<String> = []
    var selectedCEKName: Set<String> = []
    var isLoadingAlwaysEncrypted = false

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID, initialDatabase: String?) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
        self.selectedDatabase = initialDatabase
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    // MARK: - Data Loading

    func loadDatabases() async {
        do {
            let dbs = try await session.listDatabases()
            databaseList = dbs.sorted()
            if selectedDatabase == nil, let first = databaseList.first {
                selectedDatabase = first
            }
            if let db = selectedDatabase {
                await selectDatabase(db)
            }
        } catch {
            panelState?.appendMessage("Failed to load databases: \(error.localizedDescription)", severity: .error)
        }
    }

    func selectDatabase(_ database: String) async {
        selectedDatabase = database
        _ = try? await session.sessionForDatabase(database)
        isInitialized = true
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let mssql = session as? MSSQLSession else { return }
        _ = try? await session.sessionForDatabase(selectedDatabase ?? "")

        switch selectedSection {
        case .users:
            await loadUsers(mssql: mssql)
        case .roles:
            await loadRoles(mssql: mssql)
        case .appRoles:
            await loadAppRoles(mssql: mssql)
        case .schemas:
            await loadSchemas(mssql: mssql)
        case .masking:
            await loadMaskedColumns(mssql: mssql)
        case .securityPolicies:
            await loadSecurityPolicies(mssql: mssql)
        case .auditSpecifications:
            await loadDBAuditSpecs(mssql: mssql)
        case .alwaysEncrypted:
            await loadAlwaysEncrypted(mssql: mssql)
        }
    }

    private func loadUsers(mssql: MSSQLSession) async {
        isLoadingUsers = true
        defer { isLoadingUsers = false }
        do {
            users = try await mssql.security.listUsers()
        } catch {
            panelState?.appendMessage("Failed to load users: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadRoles(mssql: MSSQLSession) async {
        isLoadingRoles = true
        defer { isLoadingRoles = false }
        do {
            roles = try await mssql.security.listRoles()
        } catch {
            panelState?.appendMessage("Failed to load roles: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadAppRoles(mssql: MSSQLSession) async {
        isLoadingAppRoles = true
        defer { isLoadingAppRoles = false }
        do {
            appRoles = try await mssql.security.listApplicationRoles()
        } catch {
            panelState?.appendMessage("Failed to load application roles: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadSchemas(mssql: MSSQLSession) async {
        isLoadingSchemas = true
        defer { isLoadingSchemas = false }
        do {
            schemas = try await mssql.security.listSchemas()
        } catch {
            panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Actions

    func dropUser(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping user \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.dropUser(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped user '\(name)'")
            await loadUsers(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop user '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropRole(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping role \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.dropRole(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped role '\(name)'")
            await loadRoles(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop role '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropSchema(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping schema \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try? await session.sessionForDatabase(selectedDatabase ?? "")
            try await mssql.security.dropSchema(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped schema '\(name)'")
            await loadSchemas(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop schema '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }
}
