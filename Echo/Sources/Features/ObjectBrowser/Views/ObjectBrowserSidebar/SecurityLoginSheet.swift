import SwiftUI
import SQLServerKit

struct SecurityLoginSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing an existing login; nil for create mode.
    let existingLoginName: String?
    let onComplete: () -> Void

    @State private var loginName = ""
    @State private var authType: AuthType = .sql
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var defaultDatabase = "master"
    @State private var defaultLanguage = ""
    @State private var enforcePasswordPolicy = true
    @State private var enforcePasswordExpiration = false
    @State private var loginEnabled = true

    // Server Roles tab
    @State private var availableServerRoles: [RoleEntry] = []
    @State private var loadingRoles = false

    // Databases for picker
    @State private var availableDatabases: [String] = ["master"]

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var selectedTab = 0

    private var isEditing: Bool { existingLoginName != nil }

    private var isFormValid: Bool {
        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && authType == .sql {
            guard !password.isEmpty, password == confirmPassword else { return false }
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "person.circle") }
                    .tag(0)
                serverRolesTab
                    .tabItem { Label("Server Roles", systemImage: "shield") }
                    .tag(1)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            loadInitialData()
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
        .padding(SpacingTokens.md2)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
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
                    SecureField("Password", text: $password)
                    if !isEditing {
                        SecureField("Confirm Password", text: $confirmPassword)
                    }
                    Toggle("Enforce password policy", isOn: $enforcePasswordPolicy)
                    Toggle("Enforce password expiration", isOn: $enforcePasswordExpiration)
                }
            }

            Section("Defaults") {
                Picker("Default Database", selection: $defaultDatabase) {
                    ForEach(availableDatabases, id: \.self) { db in
                        Text(db).tag(db)
                    }
                }
            }

            Section("Status") {
                Toggle("Login enabled", isOn: $loginEnabled)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Server Roles Tab

    private var serverRolesTab: some View {
        Form {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        guard let mssql = session.session as? MSSQLSession else { return }

        Task {
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

            // If editing, load existing login properties
            if let existingName = existingLoginName {
                do {
                    let ssec = mssql.makeServerSecurityClient()
                    let logins = try await ssec.listLogins()
                    if let login = logins.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                        await MainActor.run {
                            loginName = login.name
                            loginEnabled = !login.isDisabled
                            defaultDatabase = login.defaultDatabase ?? "master"
                            switch login.type {
                            case .sql: authType = .sql
                            default: authType = .windows
                            }
                        }
                    }
                } catch { }
            }
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
                    defaultDatabase: defaultDatabase
                ))
            } else {
                // Create new login
                if authType == .sql {
                    try await ssec.createSqlLogin(name: name, password: password, options: .init(
                        defaultDatabase: defaultDatabase,
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
