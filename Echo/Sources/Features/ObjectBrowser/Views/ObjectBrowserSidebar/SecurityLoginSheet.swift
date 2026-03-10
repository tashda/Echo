import SwiftUI
import SQLServerKit

struct SecurityLoginSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing an existing login; nil for create mode.
    let existingLoginName: String?
    let onComplete: () -> Void

    @State private var selectedPage: LoginPage = .general

    @State private var loginName = ""
    @State private var authType: AuthType = .sql
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var defaultDatabase = "master"
    @State private var defaultLanguage = ""
    @State private var enforcePasswordPolicy = true
    @State private var enforcePasswordExpiration = false
    @State private var loginEnabled = true

    // Server Roles
    @State private var availableServerRoles: [RoleEntry] = []
    @State private var loadingRoles = false

    // Database Mapping
    @State private var databaseMappings: [LoginDatabaseMapping] = []
    @State private var loadingMappings = false
    @State private var availableDatabases: [String] = ["master"]
    @State private var newMappingDatabase = ""
    @State private var newMappingUser = ""

    // Database mapping SSMS-style
    @State private var databaseMappingEntries: [DatabaseMappingEntry] = []
    @State private var selectedMappingDatabase: String?
    @State private var databaseRoleMemberships: [DatabaseRoleMembershipEntry] = []
    @State private var loadingDatabaseRoles = false

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isLoading = true

    private var isEditing: Bool { existingLoginName != nil }

    private var isFormValid: Bool {
        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && authType == .sql {
            guard !password.isEmpty, password == confirmPassword else { return false }
        }
        return true
    }

    private var pages: [LoginPage] {
        if isEditing {
            return [.general, .serverRoles, .databaseMapping]
        } else {
            return [.general, .serverRoles]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 170)

                Divider()

                // Detail pane
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 680, idealHeight: 520)
        .task { await loadInitialData() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading login properties\u{2026}")
                Spacer()
            }
        } else {
            Form {
                pageContent
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .serverRoles:
            serverRolesPage
        case .databaseMapping:
            databaseMappingPage
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create Login") {
                Task { await submit() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - General Page

    @ViewBuilder
    private var generalPage: some View {
        Section(isEditing ? "Login Properties" : "New Login") {
            if isEditing {
                LabeledContent("Login Name", value: loginName)
            } else {
                TextField("Login Name", text: $loginName)
            }

            Picker("Authentication", selection: $authType) {
                Text("SQL Server Authentication").tag(AuthType.sql)
                Text("Windows Authentication").tag(AuthType.windows)
            }
        }

        if authType == .sql {
            Section("Credentials") {
                SecureField("Password", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : ""))
                if !isEditing {
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                Toggle("Enforce password policy", isOn: $enforcePasswordPolicy)
                Toggle("Enforce password expiration", isOn: $enforcePasswordExpiration)
                    .disabled(!enforcePasswordPolicy)
            }
        }

        Section("Defaults") {
            Picker("Default Database", selection: $defaultDatabase) {
                ForEach(availableDatabases, id: \.self) { db in
                    Text(db).tag(db)
                }
            }
            TextField("Default Language", text: $defaultLanguage, prompt: Text("Server default"))
                .help("Leave empty to use the server default language.")
        }

        Section("Status") {
            Toggle("Login enabled", isOn: $loginEnabled)
        }
    }

    // MARK: - Server Roles Page

    @ViewBuilder
    private var serverRolesPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading server roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section("Server Role Membership") {
                ForEach($availableServerRoles) { $role in
                    Toggle(isOn: $role.isMember) {
                        HStack {
                            Text(role.name)
                            if role.isFixed {
                                Text("(fixed)")
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(role.name == "public")
                }
            }
        }
    }

    // MARK: - Database Mapping Page

    @ViewBuilder
    private var databaseMappingPage: some View {
        if loadingMappings {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database mappings\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section("Users mapped to this login") {
                Table(databaseMappingEntries, selection: $selectedMappingDatabase) {
                    TableColumn("Map") { entry in
                        Toggle("", isOn: mappingToggleBinding(for: entry.databaseName))
                            .labelsHidden()
                    }
                    .width(40)

                    TableColumn("Database") { entry in
                        Text(entry.databaseName)
                            .font(TypographyTokens.standard)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("User") { entry in
                        Text(entry.userName ?? "")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(entry.isMapped ? .primary : .tertiary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Default Schema") { entry in
                        Text(entry.defaultSchema ?? "dbo")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 100)
                }
                .tableStyle(.bordered)
                .scrollContentBackground(.visible)
                .frame(height: min(max(CGFloat(databaseMappingEntries.count) * 28 + 32, 120), 240))
                .onChange(of: selectedMappingDatabase) { _, newDB in
                    if let db = newDB {
                        Task { await loadDatabaseRoles(for: db) }
                    }
                }
            }

            if let selectedDB = selectedMappingDatabase,
               let entry = databaseMappingEntries.first(where: { $0.databaseName == selectedDB }),
               entry.isMapped {
                Section("Database role membership for: \(selectedDB)") {
                    if loadingDatabaseRoles {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading roles\u{2026}")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(.secondary)
                        }
                    } else if databaseRoleMemberships.isEmpty {
                        Text("No fixed database roles available.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($databaseRoleMemberships) { $role in
                            Toggle(role.roleName, isOn: $role.isMember)
                                .onChange(of: role.isMember) { _, newValue in
                                    Task { await toggleDatabaseRole(database: selectedDB, role: role.roleName, isMember: newValue) }
                                }
                        }
                    }
                }
            } else if selectedMappingDatabase != nil {
                Section("Database role membership") {
                    Text("Map the login to this database first to manage role membership.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func mappingToggleBinding(for database: String) -> Binding<Bool> {
        Binding(
            get: { databaseMappingEntries.first(where: { $0.databaseName == database })?.isMapped ?? false },
            set: { newValue in
                Task {
                    if newValue {
                        await mapToDatabase(database: database)
                    } else {
                        await unmapFromDatabase(database: database)
                    }
                }
            }
        )
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        guard let mssql = session.session as? MSSQLSession else {
            isLoading = false
            return
        }

        // Load databases
        do {
            let dbs = try await session.session.listDatabases()
            await MainActor.run { availableDatabases = dbs.sorted() }
        } catch { }

        // Load server roles
        loadingRoles = true
        do {
            let ssec = mssql.makeServerSecurityClient()
            let roles = try await ssec.listServerRoles()
            var entries = roles.map { role in
                RoleEntry(name: role.name, isFixed: role.isFixed, isMember: false)
            }

            // If editing, check which roles this login is a member of
            if let loginName = existingLoginName {
                for i in entries.indices {
                    let members = try await ssec.listServerRoleMembers(role: entries[i].name)
                    if members.contains(where: { $0.caseInsensitiveCompare(loginName) == .orderedSame }) {
                        entries[i].isMember = true
                    }
                }
                entries.sort { a, b in
                    if a.isMember != b.isMember { return a.isMember }
                    return a.name < b.name
                }
            }

            await MainActor.run {
                availableServerRoles = entries
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        // If editing, load existing login properties and database mappings
        if let existingName = existingLoginName {
            do {
                let ssec = mssql.makeServerSecurityClient()
                let logins = try await ssec.listLogins(includeSystemLogins: true)
                if let login = logins.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    await MainActor.run {
                        loginName = login.name
                        loginEnabled = !login.isDisabled
                        defaultDatabase = login.defaultDatabase ?? "master"
                        defaultLanguage = login.defaultLanguage ?? ""
                        enforcePasswordPolicy = login.isPolicyChecked ?? true
                        enforcePasswordExpiration = login.isExpirationChecked ?? false
                        switch login.type {
                        case .sql: authType = .sql
                        default: authType = .windows
                        }
                    }
                }
            } catch { }

            // Load database mappings
            loadingMappings = true
            do {
                let ssec = mssql.makeServerSecurityClient()
                let mappings = try await ssec.listLoginDatabaseMappings(login: existingName)
                let mappedSet = Dictionary(uniqueKeysWithValues: mappings.map { ($0.databaseName, $0) })
                let allDbs = availableDatabases

                await MainActor.run {
                    databaseMappings = mappings
                    databaseMappingEntries = allDbs.map { db in
                        if let mapping = mappedSet[db] {
                            return DatabaseMappingEntry(databaseName: db, isMapped: true, userName: mapping.userName, defaultSchema: mapping.defaultSchema)
                        } else {
                            return DatabaseMappingEntry(databaseName: db, isMapped: false, userName: nil, defaultSchema: nil)
                        }
                    }
                    loadingMappings = false
                }
            } catch {
                await MainActor.run { loadingMappings = false }
            }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Database Mapping Actions

    private func mapToDatabase(database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let ssec = mssql.makeServerSecurityClient()
            try await ssec.mapLoginToDatabase(login: name, database: database)
            await reloadMappingEntries()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func unmapFromDatabase(database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        do {
            let ssec = mssql.makeServerSecurityClient()
            try await ssec.unmapLoginFromDatabase(login: name, database: database, userName: entry?.userName)
            await reloadMappingEntries()
            if selectedMappingDatabase == database {
                await MainActor.run { databaseRoleMemberships = [] }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func reloadMappingEntries() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let ssec = mssql.makeServerSecurityClient()
            let mappings = try await ssec.listLoginDatabaseMappings(login: name)
            let mappedSet = Dictionary(uniqueKeysWithValues: mappings.map { ($0.databaseName, $0) })

            await MainActor.run {
                databaseMappings = mappings
                databaseMappingEntries = availableDatabases.map { db in
                    if let mapping = mappedSet[db] {
                        return DatabaseMappingEntry(databaseName: db, isMapped: true, userName: mapping.userName, defaultSchema: mapping.defaultSchema)
                    } else {
                        return DatabaseMappingEntry(databaseName: db, isMapped: false, userName: nil, defaultSchema: nil)
                    }
                }
            }
        } catch { }
    }

    private func loadDatabaseRoles(for database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        guard let userName = entry?.userName, entry?.isMapped == true else {
            await MainActor.run { databaseRoleMemberships = [] }
            return
        }

        await MainActor.run { loadingDatabaseRoles = true }
        do {
            let ssec = mssql.makeServerSecurityClient()
            let roles = try await ssec.listDatabaseRolesForUser(database: database, userName: userName)
            await MainActor.run {
                databaseRoleMemberships = roles.map { DatabaseRoleMembershipEntry(roleName: $0.roleName, isMember: $0.isMember) }
                loadingDatabaseRoles = false
            }
        } catch {
            await MainActor.run { loadingDatabaseRoles = false }
        }
    }

    private func toggleDatabaseRole(database: String, role: String, isMember: Bool) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        guard let userName = entry?.userName else { return }

        do {
            let ssec = mssql.makeServerSecurityClient()
            if isMember {
                try await ssec.addUserToDatabaseRole(database: database, userName: userName, role: role)
            } else {
                try await ssec.removeUserFromDatabaseRole(database: database, userName: userName, role: role)
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            // Reload to get accurate state
            await loadDatabaseRoles(for: database)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Login name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let ssec = mssql.makeServerSecurityClient()

            if isEditing {
                // Update login properties
                if authType == .sql && !password.isEmpty {
                    try await ssec.setLoginPassword(name: name, newPassword: password)
                }
                try await ssec.enableLogin(name: name, enabled: loginEnabled)
                try await ssec.alterLogin(name: name, options: .init(
                    defaultDatabase: defaultDatabase,
                    defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
                    checkPolicy: authType == .sql ? enforcePasswordPolicy : nil,
                    checkExpiration: authType == .sql ? enforcePasswordExpiration : nil
                ))
            } else {
                // Create new login
                if authType == .sql {
                    try await ssec.createSqlLogin(name: name, password: password, options: .init(
                        defaultDatabase: defaultDatabase,
                        defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
                        checkPolicy: enforcePasswordPolicy,
                        checkExpiration: enforcePasswordExpiration
                    ))
                } else {
                    try await ssec.createWindowsLogin(name: name)
                }

                if !loginEnabled {
                    try await ssec.enableLogin(name: name, enabled: false)
                }
            }

            // Sync server role memberships
            for role in availableServerRoles where role.name != "public" {
                let currentMembers = try await ssec.listServerRoleMembers(role: role.name)
                let isCurrentlyMember = currentMembers.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })

                if role.isMember && !isCurrentlyMember {
                    try await ssec.addMemberToServerRole(role: role.name, principal: name)
                } else if !role.isMember && isCurrentlyMember {
                    try await ssec.removeMemberFromServerRole(role: role.name, principal: name)
                }
            }

            await MainActor.run {
                isSubmitting = false
                onComplete()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Supporting Types

private enum LoginPage: String, Hashable {
    case general
    case serverRoles
    case databaseMapping

    var title: String {
        switch self {
        case .general: "General"
        case .serverRoles: "Server Roles"
        case .databaseMapping: "User Mapping"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.circle"
        case .serverRoles: "shield"
        case .databaseMapping: "externaldrive.connected.to.line.below"
        }
    }
}

private enum AuthType: Hashable {
    case sql
    case windows
}

private struct RoleEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
}

private struct DatabaseMappingEntry: Identifiable, Hashable {
    var id: String { databaseName }
    let databaseName: String
    var isMapped: Bool
    var userName: String?
    var defaultSchema: String?
}

private struct DatabaseRoleMembershipEntry: Identifiable, Hashable {
    var id: String { roleName }
    let roleName: String
    var isMember: Bool
}
