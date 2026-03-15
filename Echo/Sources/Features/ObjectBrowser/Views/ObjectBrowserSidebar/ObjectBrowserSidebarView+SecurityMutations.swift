import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Security Mutation Actions (Drop, Enable, Create)

extension ObjectBrowserSidebarView {
    // MARK: - MSSQL Actions

    func dropMSSQLLogin(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropLogin(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Login '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func dropMSSQLUser(name: String, database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            _ = try? await session.session.simpleQuery("USE [\(database)]")
            let sec = mssql.security
            try await sec.dropUser(name: name)
            // Reload db security
            if let structure = session.databaseStructure,
               let db = structure.databases.first(where: { $0.name == database }) {
                loadDatabaseSecurity(database: db, session: session)
            }
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "User '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func createMSSQLServerRole(session: ConnectionSession) async {
        // Open a script tab with a CREATE SERVER ROLE template
        openScriptTab(sql: "CREATE SERVER ROLE [NewServerRole];", session: session)
    }

    func dropMSSQLServerRole(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropServerRole(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Server role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    // MARK: - Drop Security Principal Dispatch

    func executeDropSecurityPrincipal(_ target: ObjectBrowserSidebarViewModel.DropSecurityPrincipalTarget, session: ConnectionSession) async {
        switch target.kind {
        case .pgRole:
            await dropPGRole(name: target.name, session: session)
        case .mssqlLogin:
            await dropMSSQLLogin(name: target.name, session: session)
        case .mssqlUser:
            if let db = target.databaseName {
                await dropMSSQLUser(name: target.name, database: db, session: session)
            }
        case .mssqlServerRole:
            await dropMSSQLServerRole(name: target.name, session: session)
        }
    }

    // MARK: - PostgreSQL Actions

    func dropPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.security.dropUser(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func reassignPGRole(name: String, session: ConnectionSession) async {
        guard session.session is PostgresSession else { return }
        // Open a script tab with a REASSIGN OWNED template
        let sql = """
        -- Reassign all objects owned by "\(name)" to another role.
        -- Replace "target_role" with the role to receive the objects.
        REASSIGN OWNED BY "\(name)" TO "target_role";
        """
        openScriptTab(sql: sql, session: session)
    }

    // MARK: - MSSQL Login Enable/Disable

    func enableMSSQLLogin(name: String, enabled: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.enableLogin(name: name, enabled: enabled)
            loadServerSecurity(session: session)
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityToggleFailed, message: "Failed to \(enabled ? "enable" : "disable") login: \(readableErrorMessage(error))")
            }
        }
    }
}
