import SwiftUI
import PostgresKit
import SQLServerKit

extension ObjectBrowserSidebarView {
    func loadServerSecurity(session: ConnectionSession) {
        Task {
            await loadServerSecurityAsync(session: session)
        }
    }

    func loadServerSecurityAsync(session: ConnectionSession) async {
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .serverSecurity)
        viewModel.beginLoading(key)

        switch session.connection.databaseType {
        case .microsoftSQL:
            viewModel.finishLoading(key, items: await loadMSSQLServerSecurity(session: session))
        case .postgresql:
            viewModel.finishLoading(key, items: await loadPostgresServerSecurity(session: session))
        case .mysql, .sqlite:
            viewModel.finishLoading(key, items: [:])
        }
    }

    private func loadMSSQLServerSecurity(session: ConnectionSession) async -> [ExplorerNodeKind: [ExplorerItem]] {
        guard let mssql = session.session as? MSSQLSession else { return [:] }
        let security = mssql.serverSecurity
        let certificateTypes: Set<ServerLoginType> = [.certificate, .asymmetricKey]

        let logins = (try? await security.listLogins(includeSystemLogins: false)) ?? []
        let loginItems: [(isCertificate: Bool, item: ExplorerItem)] = logins.map { login in
            let type = loginTypeDisplayName(login.type)
            return (certificateTypes.contains(login.type), ExplorerItem(
                id: login.name,
                name: login.name,
                detail: login.isDisabled ? "\(type) · Disabled" : type,
                isDisabled: login.isDisabled,
                symbol: login.isDisabled ? "person.crop.circle.badge.xmark" : nil,
                payload: .login(type: type)
            ))
        }
        let roles = (try? await security.listServerRoles()) ?? []
        let credentials = (try? await security.listCredentials()) ?? []

        return [
            .logins: loginItems.filter { !$0.isCertificate }.map(\.item),
            .certificateLogins: loginItems.filter(\.isCertificate).map(\.item),
            .serverRoles: roles.map {
                ExplorerItem(id: $0.name, name: $0.name, detail: $0.isFixed ? "Fixed" : nil, payload: .serverRole(isFixed: $0.isFixed))
            },
            .credentials: credentials.map {
                ExplorerItem(id: $0.name, name: $0.name, detail: $0.identity, payload: .credential(identity: $0.identity ?? ""))
            },
        ]
    }

    private func loadPostgresServerSecurity(session: ConnectionSession) async -> [ExplorerNodeKind: [ExplorerItem]] {
        guard let pg = session.session as? PostgresSession else { return [:] }
        let roles = (try? await pg.client.security.listRoles()) ?? []

        var loginRoles: [ExplorerItem] = []
        var groupRoles: [ExplorerItem] = []
        for role in roles {
            let type = role.isSuperuser ? "Superuser" : role.canLogin ? "Login Role" : "Group Role"
            if role.isSuperuser || role.canLogin {
                loginRoles.append(ExplorerItem(id: role.name, name: role.name, detail: type, payload: .login(type: type)))
            } else {
                groupRoles.append(ExplorerItem(
                    id: role.name,
                    name: role.name,
                    detail: type,
                    symbol: ExplorerNodeKind.groupRoles.symbol,
                    role: .roles,
                    payload: .login(type: type)
                ))
            }
        }
        return [.loginRoles: loginRoles, .groupRoles: groupRoles]
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
