import SwiftUI
import Combine
import SQLServerKit

@MainActor
final class SecuritySidebarViewModel: ObservableObject {
    struct DbUser: Identifiable, Hashable { let id: String; let name: String; let type: String; let defaultSchema: String? }
    struct DbRole: Identifiable, Hashable { let id: String; let name: String; let isFixed: Bool }
    struct ServerLogin: Identifiable, Hashable { let id: String; let name: String; let type: String; let disabled: Bool }
    struct ServerRole: Identifiable, Hashable { let id: String; let name: String; let isFixed: Bool }

    @Published private(set) var dbUsers: [DbUser] = []
    @Published private(set) var dbRoles: [DbRole] = []
    @Published private(set) var serverLogins: [ServerLogin] = []
    @Published private(set) var serverRoles: [ServerRole] = []
    @Published private(set) var errorMessage: String?

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

        async let loadDb: Void = loadDatabaseSecurity(mssql: mssql)
        async let loadServer: Void = loadServerSecurity(mssql: mssql)
        _ = await (loadDb, loadServer)
    }

    private func loadDatabaseSecurity(mssql: MSSQLSession) async {
        do {
            let sec = mssql.makeDatabaseSecurityClient()
            let users = try await sec.listUsers()
            let roles = try await sec.listRoles()
            let mappedUsers: [DbUser] = users.map { u in .init(id: u.name, name: u.name, type: u.type, defaultSchema: u.defaultSchema) }
            let mappedRoles: [DbRole] = roles.map { r in .init(id: r.name, name: r.name, isFixed: r.isFixedRole) }
            await MainActor.run { self.dbUsers = mappedUsers; self.dbRoles = mappedRoles }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadServerSecurity(mssql: MSSQLSession) async {
        do {
            let ssec = mssql.makeServerSecurityClient()
            let logins = try await ssec.listLogins()
            let roles = try await ssec.listServerRoles()
            let mappedLogins: [ServerLogin] = logins.map { l in .init(id: l.name, name: l.name, type: l.type.rawValue, disabled: l.isDisabled) }
            let mappedRoles: [ServerRole] = roles.map { r in .init(id: r.name, name: r.name, isFixed: r.isFixed) }
            await MainActor.run { self.serverLogins = mappedLogins; self.serverRoles = mappedRoles }
        } catch {
            // Server-level enumeration may require elevated perms; don't block DB lists
            await MainActor.run { self.serverLogins = []; self.serverRoles = [] }
        }
    }
}

struct SecuritySidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var viewModel = SecuritySidebarViewModel()
    @State private var searchText: String = ""

    private var filteredDbUsers: [SecuritySidebarViewModel.DbUser] {
        if searchText.isEmpty { return viewModel.dbUsers }
        return viewModel.dbUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredDbRoles: [SecuritySidebarViewModel.DbRole] {
        if searchText.isEmpty { return viewModel.dbRoles }
        return viewModel.dbRoles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredLogins: [SecuritySidebarViewModel.ServerLogin] {
        if searchText.isEmpty { return viewModel.serverLogins }
        return viewModel.serverLogins.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredServerRoles: [SecuritySidebarViewModel.ServerRole] {
        if searchText.isEmpty { return viewModel.serverRoles }
        return viewModel.serverRoles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search users, roles, logins…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await viewModel.reload(for: activeSession) }
                } label: { Image(systemName: "arrow.clockwise") }
                .help("Reload security lists")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Database Users (") { Text("\(viewModel.dbUsers.count)") } suffix: { Text(")") }
                    ForEach(filteredDbUsers) { user in
                        HStack {
                            Image(systemName: "person.fill")
                            Text(user.name).font(.body)
                            Spacer()
                            if let schema = user.defaultSchema, !schema.isEmpty {
                                Text(schema).foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    Divider()

                    sectionHeader("Database Roles (") { Text("\(viewModel.dbRoles.count)") } suffix: { Text(")") }
                    ForEach(filteredDbRoles) { role in
                        HStack {
                            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                            Text(role.name)
                            Spacer()
                            if role.isFixed { Text("fixed").foregroundColor(.secondary) }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    Divider()

                    sectionHeader("Server Logins (") { Text("\(viewModel.serverLogins.count)") } suffix: { Text(")") }
                    ForEach(filteredLogins) { login in
                        HStack {
                            Image(systemName: login.disabled ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                            Text(login.name)
                            Spacer()
                            Text(login.type).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    Divider()

                    sectionHeader("Server Roles (") { Text("\(viewModel.serverRoles.count)") } suffix: { Text(")") }
                    ForEach(filteredServerRoles) { role in
                        HStack {
                            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                            Text(role.name)
                            Spacer()
                            if role.isFixed { Text("fixed").foregroundColor(.secondary) }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }

            if let message = viewModel.errorMessage {
                Text(message).foregroundColor(.secondary).padding([.horizontal, .bottom], 8)
            }
        }
        .onAppear { Task { await viewModel.reload(for: activeSession) } }
        .onChange(of: selectedConnectionID) { _ in Task { await viewModel.reload(for: activeSession) } }
    }

    private var activeSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return appModel.sessionManager.sessionForConnection(id)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, @ViewBuilder count: () -> some View, @ViewBuilder suffix: () -> some View) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.headline)
            count()
            suffix()
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

