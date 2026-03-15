import SwiftUI
import SQLServerKit

@MainActor @Observable
final class SecuritySidebarViewModel {
    struct DbUser: Identifiable, Hashable { let id: String; let name: String; let type: String; let defaultSchema: String? }
    struct DbRole: Identifiable, Hashable { let id: String; let name: String; let isFixed: Bool }
    struct ServerLogin: Identifiable, Hashable { let id: String; let name: String; let type: String; let disabled: Bool }
    struct ServerRole: Identifiable, Hashable { let id: String; let name: String; let isFixed: Bool }

    private(set) var dbUsers: [DbUser] = []
    private(set) var dbRoles: [DbRole] = []
    private(set) var serverLogins: [ServerLogin] = []
    private(set) var serverRoles: [ServerRole] = []
    private(set) var errorMessage: String?

    func reload(for session: ConnectionSession?) async {
        guard let session, session.connection.databaseType == .microsoftSQL else {
            await MainActor.run {
                self.dbUsers = []; self.dbRoles = []; self.serverLogins = []; self.serverRoles = []
                self.errorMessage = "Connect to a Microsoft SQL Server to view Security."
            }
            return
        }
        await MainActor.run { self.errorMessage = nil }

        // Downcast to MSSQLSession to use typed clients
        guard let mssql = session.session as? MSSQLSession else {
            await MainActor.run { self.errorMessage = "Security is only available for MSSQL sessions." }
            return
        }

        // Execute sequentially to avoid data races
        await loadDatabaseSecurity(mssql: mssql)
        await loadServerSecurity(mssql: mssql)
    }

    private func loadDatabaseSecurity(mssql: MSSQLSession) async {
        do {
            let users = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let sec = mssql.security
                    do {
                        let result = try await sec.listUsers()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            let roles = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let sec = mssql.security
                    do {
                        let result = try await sec.listRoles()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            let mappedUsers: [DbUser] = users.map { u in
                .init(id: u.name, name: u.name, type: String(describing: u.type), defaultSchema: u.defaultSchema)
            }
            let mappedRoles: [DbRole] = roles.map { r in
                .init(id: r.name, name: r.name, isFixed: false)
            }

            await MainActor.run {
                self.dbUsers = mappedUsers
                self.dbRoles = mappedRoles
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func loadServerSecurity(mssql: MSSQLSession) async {
        do {
            let logins = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let ssec = mssql.serverSecurity
                    do {
                        let result = try await ssec.listLogins()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            let roles = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let ssec = mssql.serverSecurity
                    do {
                        let result = try await ssec.listServerRoles()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            let mappedLogins: [ServerLogin] = logins.map { l in
                .init(id: l.name, name: l.name, type: String(describing: l.type), disabled: l.isDisabled)
            }
            let mappedRoles: [ServerRole] = roles.map { r in
                .init(id: r.name, name: r.name, isFixed: r.isFixed)
            }

            await MainActor.run {
                self.serverLogins = mappedLogins
                self.serverRoles = mappedRoles
            }
        } catch {
            await MainActor.run {
                self.serverLogins = []
                self.serverRoles = []
            }
        }
    }
}
