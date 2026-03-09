import SwiftUI
import PostgresKit

struct SecurityPGRoleSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing; nil for create mode.
    let existingRoleName: String?
    let onComplete: () -> Void

    @State private var selectedPage: PGRolePage = .general

    @State private var roleName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var canLogin = true
    @State private var isSuperuser = false
    @State private var canCreateDB = false
    @State private var canCreateRole = false
    @State private var inherit = true
    @State private var isReplication = false
    @State private var bypassRLS = false
    @State private var connectionLimit = -1
    @State private var validUntil = ""

    // Membership: "Member Of" (roles this role belongs to)
    @State private var memberOfEntries: [PGRoleMemberEntry] = []
    // Membership: "Members" (roles that belong to this role)
    @State private var memberEntries: [PGRoleMemberEntry] = []
    @State private var loadingRoles = false

    // Parameters
    @State private var roleParameters: [PostgresDatabaseParameter] = []

    // Security labels
    @State private var securityLabels: [PostgresSecurityLabel] = []

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isLoading = true

    private var isEditing: Bool { existingRoleName != nil }

    private var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && !password.isEmpty && password != confirmPassword { return false }
        return true
    }

    private var pages: [PGRolePage] {
        if isEditing {
            return [.general, .privileges, .membership, .parameters, .securityLabels, .sql]
        } else {
            return [.general, .privileges, .membership]
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

            // Bottom bar
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
                ProgressView("Loading role properties\u{2026}")
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
        case .privileges:
            privilegesPage
        case .membership:
            membershipPage
        case .parameters:
            parametersPage
        case .securityLabels:
            securityLabelsPage
        case .sql:
            sqlPage
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

            Button(isEditing ? "Save" : "Create Role") {
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
        Section(isEditing ? "Role Properties" : "New Login/Group Role") {
            if isEditing {
                LabeledContent("Role Name", value: roleName)
            } else {
                TextField("Role Name", text: $roleName)
            }
        }

        Section("Authentication") {
            SecureField("Password", text: $password, prompt: Text(isEditing ? "Leave empty to keep current" : "Optional"))
            if !isEditing {
                SecureField("Confirm Password", text: $confirmPassword)
            }
        }

        Section("Connection") {
            Toggle("Can login", isOn: $canLogin)
            LabeledContent("Connection limit") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $connectionLimit, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(connectionLimit == -1 ? "(unlimited)" : "")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.tertiary)
                }
            }
        }

        Section("Account Expires") {
            TextField("Valid until", text: $validUntil, prompt: Text("YYYY-MM-DD HH:MM:SS or empty for no expiry"))
                .help("Account expiration timestamp. Leave empty for no expiry.")
        }
    }

    // MARK: - Privileges Page

    @ViewBuilder
    private var privilegesPage: some View {
        Section("Role Privileges") {
            Toggle("Superuser", isOn: $isSuperuser)
            Toggle("Create databases", isOn: $canCreateDB)
            Toggle("Create roles", isOn: $canCreateRole)
            Toggle("Inherit privileges", isOn: $inherit)
            Toggle("Replication", isOn: $isReplication)
            Toggle("Bypass row-level security", isOn: $bypassRLS)
        }

        Section {
            Text("Superuser grants all privileges and bypasses all permission checks. Bypass RLS allows the role to bypass all row-level security policies.")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Membership Page

    @ViewBuilder
    private var membershipPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            if !memberOfEntries.isEmpty || !isEditing {
                Section("Member Of") {
                    if memberOfEntries.isEmpty {
                        Text("No other roles available.")
                            .foregroundStyle(.secondary)
                            .font(TypographyTokens.detail)
                    } else {
                        ForEach($memberOfEntries) { $entry in
                            Toggle(isOn: $entry.isMember) {
                                Text(entry.name)
                            }
                        }
                    }
                }
            }

            if isEditing {
                Section("Members") {
                    if memberEntries.isEmpty {
                        Text("No roles are members of this role.")
                            .foregroundStyle(.secondary)
                            .font(TypographyTokens.detail)
                    } else {
                        ForEach($memberEntries) { $entry in
                            Toggle(isOn: $entry.isMember) {
                                Text(entry.name)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Parameters Page

    @ViewBuilder
    private var parametersPage: some View {
        if roleParameters.isEmpty {
            Section {
                Text("No role-level parameters configured.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.standard)
            }
        } else {
            Section("Role Parameters") {
                ForEach(Array(roleParameters.enumerated()), id: \.offset) { _, param in
                    LabeledContent(param.name, value: param.value)
                }
            }
        }
    }

    // MARK: - Security Labels Page

    @ViewBuilder
    private var securityLabelsPage: some View {
        if securityLabels.isEmpty {
            Section {
                Text("No security labels assigned to this role.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.standard)
            }
        } else {
            Section("Security Labels") {
                ForEach(Array(securityLabels.enumerated()), id: \.offset) { _, label in
                    LabeledContent(label.provider, value: label.label)
                }
            }
        }
    }

    // MARK: - SQL Page

    @ViewBuilder
    private var sqlPage: some View {
        Section("Generated SQL") {
            let sql = generateSQL()
            Text(sql)
                .font(TypographyTokens.monospaced)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
        }
    }

    private func generateSQL() -> String {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "-- Enter a role name first" }

        if isEditing {
            var parts: [String] = ["ALTER ROLE \"\(name)\""]
            var attrs: [String] = []
            if isSuperuser { attrs.append("SUPERUSER") } else { attrs.append("NOSUPERUSER") }
            if canCreateDB { attrs.append("CREATEDB") } else { attrs.append("NOCREATEDB") }
            if canCreateRole { attrs.append("CREATEROLE") } else { attrs.append("NOCREATEROLE") }
            if canLogin { attrs.append("LOGIN") } else { attrs.append("NOLOGIN") }
            if inherit { attrs.append("INHERIT") } else { attrs.append("NOINHERIT") }
            if isReplication { attrs.append("REPLICATION") } else { attrs.append("NOREPLICATION") }
            if bypassRLS { attrs.append("BYPASSRLS") } else { attrs.append("NOBYPASSRLS") }
            if connectionLimit != -1 { attrs.append("CONNECTION LIMIT \(connectionLimit)") }
            if !validUntil.isEmpty { attrs.append("VALID UNTIL '\(validUntil)'") }
            parts.append("WITH \(attrs.joined(separator: " "))")
            return parts.joined(separator: "\n") + ";"
        } else {
            var attrs: [String] = []
            if isSuperuser { attrs.append("SUPERUSER") } else { attrs.append("NOSUPERUSER") }
            if canCreateDB { attrs.append("CREATEDB") } else { attrs.append("NOCREATEDB") }
            if canCreateRole { attrs.append("CREATEROLE") } else { attrs.append("NOCREATEROLE") }
            if canLogin { attrs.append("LOGIN") } else { attrs.append("NOLOGIN") }
            if inherit { attrs.append("INHERIT") } else { attrs.append("NOINHERIT") }
            if isReplication { attrs.append("REPLICATION") } else { attrs.append("NOREPLICATION") }
            return "CREATE ROLE \"\(name)\" WITH \(attrs.joined(separator: " "));"
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        guard let pg = session.session as? PostgresSession else {
            isLoading = false
            return
        }

        let admin = PostgresAdmin(client: pg.client, logger: pg.logger)

        // Load available roles for membership
        loadingRoles = true
        do {
            let roles = try await admin.listRoles()
            let currentName = existingRoleName ?? ""

            // "Member Of" entries: other roles this role can be a member of
            var moEntries = roles
                .filter { $0.name != currentName }
                .map { PGRoleMemberEntry(name: $0.name, isMember: false) }

            // "Members" entries: other roles that are members of this role
            var mEntries = roles
                .filter { $0.name != currentName }
                .map { PGRoleMemberEntry(name: $0.name, isMember: false) }

            // Check current memberships if editing
            if !currentName.isEmpty {
                let memberOf = try await admin.listMemberOf(role: currentName)
                for i in moEntries.indices {
                    if memberOf.contains(where: { $0.roleName == moEntries[i].name }) {
                        moEntries[i].isMember = true
                    }
                }
                moEntries.sort { a, b in
                    if a.isMember != b.isMember { return a.isMember }
                    return a.name < b.name
                }

                let members = try await admin.listMembers(of: currentName)
                for i in mEntries.indices {
                    if members.contains(where: { $0.memberName == mEntries[i].name }) {
                        mEntries[i].isMember = true
                    }
                }
                mEntries.sort { a, b in
                    if a.isMember != b.isMember { return a.isMember }
                    return a.name < b.name
                }
            }

            await MainActor.run {
                memberOfEntries = moEntries
                memberEntries = mEntries
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        // If editing, load existing role properties
        if let existingName = existingRoleName {
            do {
                let roles = try await admin.listRoles()
                if let role = roles.first(where: { $0.name == existingName }) {
                    await MainActor.run {
                        roleName = role.name
                        canLogin = role.canLogin
                        isSuperuser = role.isSuperuser
                        canCreateDB = role.canCreateDB
                        canCreateRole = role.canCreateRole
                        inherit = role.inherit
                        isReplication = role.isReplication
                        bypassRLS = role.bypassRLS
                        connectionLimit = role.connectionLimit
                        validUntil = role.validUntil ?? ""
                    }

                    // Load parameters
                    let params = try await admin.fetchRoleParameters(roleOid: role.oid)
                    await MainActor.run { roleParameters = params }

                    // Load security labels
                    let labels = try await admin.fetchRoleSecurityLabels(role: existingName)
                    await MainActor.run { securityLabels = labels }
                }
            } catch { }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Submit

    private func submit() async {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Not connected to a PostgreSQL instance"
            return
        }

        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Role name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            if isEditing {
                try await pg.client.alterUser(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    validUntil: validUntil.isEmpty ? nil : validUntil
                )
            } else {
                try await pg.client.createUser(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    validUntil: validUntil.isEmpty ? nil : validUntil
                )
            }

            // Sync "Member Of" role memberships
            let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
            let currentMemberOf = try await admin.listMemberOf(role: name)

            for entry in memberOfEntries {
                let isCurrentlyMember = currentMemberOf.contains(where: {
                    $0.roleName == entry.name && $0.memberName == name
                })

                if entry.isMember && !isCurrentlyMember {
                    try await pg.client.grantRole(role: entry.name, to: name)
                } else if !entry.isMember && isCurrentlyMember {
                    try await pg.client.revokeRole(role: entry.name, from: name)
                }
            }

            // Sync "Members" role memberships (roles that are members of this role)
            if isEditing {
                let currentMembers = try await admin.listMembers(of: name)

                for entry in memberEntries {
                    let isCurrentlyMember = currentMembers.contains(where: {
                        $0.memberName == entry.name
                    })

                    if entry.isMember && !isCurrentlyMember {
                        try await pg.client.grantRole(role: name, to: entry.name)
                    } else if !entry.isMember && isCurrentlyMember {
                        try await pg.client.revokeRole(role: name, from: entry.name)
                    }
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

private enum PGRolePage: String, Hashable, CaseIterable {
    case general
    case privileges
    case membership
    case parameters
    case securityLabels
    case sql

    var title: String {
        switch self {
        case .general: "General"
        case .privileges: "Privileges"
        case .membership: "Membership"
        case .parameters: "Parameters"
        case .securityLabels: "Security Labels"
        case .sql: "SQL"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.circle"
        case .privileges: "lock.shield"
        case .membership: "person.2"
        case .parameters: "slider.horizontal.3"
        case .securityLabels: "tag"
        case .sql: "chevron.left.forwardslash.chevron.right"
        }
    }
}

private struct PGRoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var isMember: Bool
}
