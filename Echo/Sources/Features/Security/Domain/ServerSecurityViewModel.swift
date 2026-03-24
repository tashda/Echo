import Foundation
import Observation
import SQLServerKit

@Observable
final class ServerSecurityViewModel {

    enum Section: String, CaseIterable {
        case logins = "Logins"
        case serverRoles = "Server Roles"
        case credentials = "Credentials"
        case audits = "Audits"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored private let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .logins
    var isInitialized = false

    // Logins
    var logins: [ServerLoginInfo] = []
    var selectedLoginName: Set<String> = []
    var isLoadingLogins = false

    // Server Roles
    var serverRoles: [ServerRoleInfo] = []
    var selectedServerRoleName: Set<String> = []
    var isLoadingServerRoles = false

    // Credentials
    var credentials: [SQLServerServerSecurityClient.CredentialInfo] = []
    var selectedCredentialName: Set<String> = []
    var isLoadingCredentials = false

    // Audits
    var audits: [ServerAuditInfo] = []
    var selectedAuditName: Set<String> = []
    var isLoadingAudits = false

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        isInitialized = true
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let mssql = session as? MSSQLSession else { return }

        switch selectedSection {
        case .logins:
            await loadLogins(mssql: mssql)
        case .serverRoles:
            await loadServerRoles(mssql: mssql)
        case .credentials:
            await loadCredentials(mssql: mssql)
        case .audits:
            await loadAudits(mssql: mssql)
        }
    }

    private func loadLogins(mssql: MSSQLSession) async {
        isLoadingLogins = true
        defer { isLoadingLogins = false }
        do {
            logins = try await mssql.serverSecurity.listLogins()
        } catch {
            panelState?.appendMessage("Failed to load logins: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadServerRoles(mssql: MSSQLSession) async {
        isLoadingServerRoles = true
        defer { isLoadingServerRoles = false }
        do {
            serverRoles = try await mssql.serverSecurity.listServerRoles()
        } catch {
            panelState?.appendMessage("Failed to load server roles: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadCredentials(mssql: MSSQLSession) async {
        isLoadingCredentials = true
        defer { isLoadingCredentials = false }
        do {
            credentials = try await mssql.serverSecurity.listCredentials()
        } catch {
            panelState?.appendMessage("Failed to load credentials: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadAudits(mssql: MSSQLSession) async {
        isLoadingAudits = true
        defer { isLoadingAudits = false }
        do {
            audits = try await mssql.audit.listServerAudits()
        } catch {
            panelState?.appendMessage("Failed to load audits: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Actions

    func toggleAudit(_ name: String, enabled: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            try await mssql.audit.setAuditState(name: name, enabled: enabled)
            panelState?.appendMessage(enabled ? "Enabled audit '\(name)'" : "Disabled audit '\(name)'")
            await loadAudits(mssql: mssql)
        } catch {
            panelState?.appendMessage("Failed to \(enabled ? "enable" : "disable") audit '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropAudit(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping audit \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.audit.dropServerAudit(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped audit '\(name)'")
            await loadAudits(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop audit '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropLogin(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping login \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.serverSecurity.dropLogin(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped login '\(name)'")
            await loadLogins(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop login '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func toggleLogin(_ name: String, enabled: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            try await mssql.serverSecurity.enableLogin(name: name, enabled: enabled)
            panelState?.appendMessage(enabled ? "Enabled login '\(name)'" : "Disabled login '\(name)'")
            await loadLogins(mssql: mssql)
        } catch {
            panelState?.appendMessage("Failed to \(enabled ? "enable" : "disable") login '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }

    func dropCredential(_ name: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Dropping credential \(name)", connectionSessionID: connectionSessionID)
        do {
            try await mssql.serverSecurity.dropCredential(name: name)
            handle?.succeed()
            panelState?.appendMessage("Dropped credential '\(name)'")
            await loadCredentials(mssql: mssql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to drop credential '\(name)': \(error.localizedDescription)", severity: .error)
        }
    }
}
