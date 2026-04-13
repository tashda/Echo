import SwiftUI
import PostgresKit
import SQLServerKit

extension ExperimentalObjectBrowserSidebarView {
    func loadServerSecurityIfNeeded(session: ConnectionSession) {
        let connID = session.connection.id
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
            || !(viewModel.securityServerRolesBySession[connID] ?? []).isEmpty
            || !(viewModel.securityCredentialsBySession[connID] ?? []).isEmpty
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        if !hasData && !isLoading {
            loadServerSecurity(session: session)
        }
    }

    func loadServerSecurity(session: ConnectionSession) {
        Task {
            await loadServerSecurityAsync(session: session)
        }
    }

    func loadServerSecurityAsync(session: ConnectionSession) async {
        let connID = session.connection.id
        viewModel.securityServerLoadingBySession[connID] = true
        defer { viewModel.securityServerLoadingBySession[connID] = false }

        switch session.connection.databaseType {
        case .microsoftSQL:
            await loadMSSQLServerSecurity(session: session, connID: connID)
        case .postgresql:
            await loadPostgresServerSecurity(session: session, connID: connID)
        case .mysql, .sqlite:
            break
        }
    }

    func loadMSSQLServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let security = mssql.serverSecurity

        do {
            let logins = try await security.listLogins(includeSystemLogins: false)
            viewModel.securityLoginsBySession[connID] = logins.map {
                .init(
                    id: $0.name,
                    name: $0.name,
                    loginType: loginTypeDisplayName($0.type),
                    isDisabled: $0.isDisabled
                )
            }
        } catch {
            viewModel.securityLoginsBySession[connID] = []
        }

        do {
            let roles = try await security.listServerRoles()
            viewModel.securityServerRolesBySession[connID] = roles.map {
                .init(id: $0.name, name: $0.name, isFixed: $0.isFixed)
            }
        } catch {
            viewModel.securityServerRolesBySession[connID] = []
        }

        do {
            let credentials = try await security.listCredentials()
            viewModel.securityCredentialsBySession[connID] = credentials.map {
                .init(id: $0.name, name: $0.name, identity: $0.identity ?? "")
            }
        } catch {
            viewModel.securityCredentialsBySession[connID] = []
        }
    }

    func loadPostgresServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let pg = session.session as? PostgresSession else { return }

        do {
            let roles = try await pg.client.security.listRoles()
            viewModel.securityLoginsBySession[connID] = roles.map { role in
                let typeDescription: String
                if role.isSuperuser {
                    typeDescription = "Superuser"
                } else if role.canLogin {
                    typeDescription = "Login Role"
                } else {
                    typeDescription = "Group Role"
                }
                return .init(
                    id: role.name,
                    name: role.name,
                    loginType: typeDescription,
                    isDisabled: false
                )
            }
        } catch {
            viewModel.securityLoginsBySession[connID] = []
        }
    }

    func createMSSQLServerRole(session: ConnectionSession) {
        sheetState.newSecuritySheetSessionID = session.id
        sheetState.showNewServerRoleSheet = true
    }

    func createMSSQLCredential(session: ConnectionSession) {
        sheetState.newSecuritySheetSessionID = session.id
        sheetState.showNewCredentialSheet = true
    }

    func dropMSSQLLogin(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.serverSecurity.dropLogin(name: name)
            loadServerSecurity(session: session)
            environmentState.notificationEngine?.post(category: .securityDropped, message: "Login '\(name)' dropped")
        } catch {
            environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
        }
    }

    func dropMSSQLServerRole(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.serverSecurity.dropServerRole(name: name)
            loadServerSecurity(session: session)
            environmentState.notificationEngine?.post(category: .securityDropped, message: "Server role '\(name)' dropped")
        } catch {
            environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
        }
    }

    func enableMSSQLLogin(name: String, enabled: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.serverSecurity.enableLogin(name: name, enabled: enabled)
            loadServerSecurity(session: session)
        } catch {
            environmentState.notificationEngine?.post(
                category: .securityToggleFailed,
                message: "Failed to \(enabled ? "enable" : "disable") login: \(readableErrorMessage(error))"
            )
        }
    }

    func dropPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.security.dropUser(name: name)
            loadServerSecurity(session: session)
            environmentState.notificationEngine?.post(category: .securityDropped, message: "Role '\(name)' dropped")
        } catch {
            environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
        }
    }

    func reassignPGRole(name: String, session: ConnectionSession) async {
        let sql = """
        -- Reassign all objects owned by "\(name)" to another role.
        -- Replace "target_role" with the role to receive the objects.
        REASSIGN OWNED BY "\(name)" TO "target_role";
        """
        openScriptTab(sql: sql, session: session)
    }

    func executeDropSecurityPrincipal(
        _ target: SidebarSheetState.DropSecurityPrincipalTarget,
        session: ConnectionSession
    ) async {
        switch target.kind {
        case .pgRole:
            await dropPGRole(name: target.name, session: session)
        case .mssqlLogin:
            await dropMSSQLLogin(name: target.name, session: session)
        case .mssqlServerRole:
            await dropMSSQLServerRole(name: target.name, session: session)
        case .mssqlUser:
            break
        }
    }

    func openScriptTab(sql: String, session: ConnectionSession) {
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    func readableErrorMessage(_ error: Error) -> String {
        if let pgError = error as? PostgresKit.PostgresError {
            return pgError.message
        }
        return error.localizedDescription
    }

    func loginTypeDisplayName(_ type: ServerLoginType) -> String {
        switch type {
        case .sql: "SQL"
        case .windowsUser: "Windows"
        case .windowsGroup: "Windows Group"
        case .certificate: "Certificate"
        case .asymmetricKey: "Asymmetric Key"
        case .external: "External"
        }
    }
}
