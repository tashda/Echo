import SwiftUI
import PostgresKit

struct SecurityPGRoleSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing; nil for create mode.
    let existingRoleName: String?
    let onComplete: () -> Void

    @State var selectedPage: PGRolePage = .general

    @State var roleName = ""
    @State var password = ""
    @State var confirmPassword = ""
    @State var canLogin = true
    @State var isSuperuser = false
    @State var canCreateDB = false
    @State var canCreateRole = false
    @State var inherit = true
    @State var isReplication = false
    @State var bypassRLS = false
    @State var connectionLimit = -1
    @State var validUntil = ""

    // Membership
    @State var memberOfEntries: [PGRoleMemberEntry] = []
    @State var memberEntries: [PGRoleMemberEntry] = []
    @State var availableRolesForMemberOf: [String] = []
    @State var availableRolesForMembers: [String] = []
    @State var selectedNewMemberOfRole = ""
    @State var selectedNewMemberRole = ""
    @State var loadingRoles = false

    // Comment
    @State var roleComment = ""

    // Parameters
    @State var roleParameters: [PostgresDatabaseParameter] = []
    @State var newParamName = ""
    @State var newParamValue = ""

    // Security labels
    @State var securityLabels: [PostgresSecurityLabel] = []
    @State var newLabelProvider = ""
    @State var newLabelValue = ""

    @State var errorMessage: String?
    @State var isSubmitting = false
    @State var isLoading = true

    var isEditing: Bool { existingRoleName != nil }

    var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && !password.isEmpty && password != confirmPassword { return false }
        return true
    }

    var pages: [PGRolePage] {
        if isEditing {
            return [.general, .privileges, .membership, .parameters, .securityLabels, .sql]
        } else {
            return [.general, .privileges, .membership]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 170)

                Divider()

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

    // MARK: - Membership Table

    @ViewBuilder
    func membershipTable(entries: Binding<[PGRoleMemberEntry]>, availableRoles: [String], selectedNewRole: Binding<String>, onAdd: @escaping () -> Void, onRemove: @escaping (IndexSet) -> Void) -> some View {
        if entries.wrappedValue.isEmpty {
            Text("No memberships configured.")
                .foregroundStyle(.secondary)
                .font(TypographyTokens.detail)
        } else {
            Table(entries.wrappedValue) {
                TableColumn("Role") { entry in
                    Text(entry.name)
                        .font(TypographyTokens.standard)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Admin") { entry in
                    if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                        Toggle("", isOn: binding.adminOption)
                            .labelsHidden()
                    }
                }
                .width(50)

                TableColumn("Inherit") { entry in
                    if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                        Toggle("", isOn: binding.inheritOption)
                            .labelsHidden()
                    }
                }
                .width(50)

                TableColumn("Set") { entry in
                    if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                        Toggle("", isOn: binding.setOption)
                            .labelsHidden()
                    }
                }
                .width(50)
            }
            .tableStyle(.bordered)
            .scrollContentBackground(.visible)
            .frame(height: min(max(CGFloat(entries.wrappedValue.count) * 28 + 32, 80), 200))
        }

        HStack(spacing: SpacingTokens.xs) {
            Picker("Add role", selection: selectedNewRole) {
                Text("Select role\u{2026}").tag("")
                ForEach(availableRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }
            .labelsHidden()
            .frame(minWidth: 160)

            Button("Add") { onAdd() }
                .disabled(selectedNewRole.wrappedValue.isEmpty)

            Spacer()

            if !entries.wrappedValue.isEmpty {
                Button("Remove Selected", role: .destructive) {
                    // Remove last entry as fallback
                    if let last = entries.wrappedValue.indices.last {
                        onRemove(IndexSet(integer: last))
                    }
                }
            }
        }
    }

    // MARK: - Predefined Parameters

    static let predefinedParameters = [
        "search_path", "work_mem", "maintenance_work_mem", "temp_buffers",
        "statement_timeout", "lock_timeout", "idle_in_transaction_session_timeout",
        "log_statement", "log_min_duration_statement", "log_min_messages",
        "client_min_messages", "default_transaction_isolation", "default_transaction_read_only",
        "timezone", "DateStyle", "IntervalStyle", "client_encoding",
        "lc_messages", "lc_monetary", "lc_numeric", "lc_time",
        "temp_file_limit", "effective_cache_size", "random_page_cost", "seq_page_cost",
        "cpu_tuple_cost", "cpu_index_tuple_cost", "cpu_operator_cost",
        "enable_hashjoin", "enable_mergejoin", "enable_nestloop", "enable_seqscan",
        "enable_indexscan", "enable_indexonlyscan", "enable_bitmapscan",
        "geqo", "geqo_threshold", "from_collapse_limit", "join_collapse_limit"
    ]

    var availableParameters: [String] {
        let existing = Set(roleParameters.map(\.name))
        return Self.predefinedParameters.filter { !existing.contains($0) }
    }

    func addParameter() {
        let value = newParamValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newParamName.isEmpty, !value.isEmpty else { return }
        roleParameters.append(PostgresDatabaseParameter(name: newParamName, value: value))
        newParamName = ""
        newParamValue = ""
    }

    func addSecurityLabel() {
        let provider = newLabelProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = newLabelValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !provider.isEmpty, !label.isEmpty else { return }
        securityLabels.append(PostgresSecurityLabel(provider: provider, label: label))
        newLabelProvider = ""
        newLabelValue = ""
    }

    func generateSQL() -> String {
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

        loadingRoles = true
        do {
            let roles = try await admin.listRoles()
            let currentName = existingRoleName ?? ""
            let allRoleNames = roles.map(\.name).filter { $0 != currentName }.sorted()

            var moEntries: [PGRoleMemberEntry] = []
            var mEntries: [PGRoleMemberEntry] = []

            if !currentName.isEmpty {
                let memberOf = try await admin.listMemberOf(role: currentName)
                moEntries = memberOf.map { m in
                    PGRoleMemberEntry(
                        name: m.roleName,
                        adminOption: m.adminOption,
                        inheritOption: m.inheritOption,
                        setOption: m.setOption
                    )
                }

                let members = try await admin.listMembers(of: currentName)
                mEntries = members.map { m in
                    PGRoleMemberEntry(
                        name: m.memberName,
                        adminOption: m.adminOption,
                        inheritOption: m.inheritOption,
                        setOption: m.setOption
                    )
                }
            }

            let moNames = Set(moEntries.map(\.name))
            let mNames = Set(mEntries.map(\.name))

            await MainActor.run {
                memberOfEntries = moEntries
                memberEntries = mEntries
                availableRolesForMemberOf = allRoleNames.filter { !moNames.contains($0) }
                availableRolesForMembers = allRoleNames.filter { !mNames.contains($0) }
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

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

                    let params = try await admin.fetchRoleParameters(roleOid: role.oid)
                    await MainActor.run { roleParameters = params }

                    let labels = try await admin.fetchRoleSecurityLabels(role: existingName)
                    await MainActor.run { securityLabels = labels }

                    let comment = try await admin.fetchRoleComment(role: existingName)
                    await MainActor.run { roleComment = comment ?? "" }
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

            let admin = PostgresAdmin(client: pg.client, logger: pg.logger)

            // Sync "Member Of" memberships
            let currentMemberOf = try await admin.listMemberOf(role: name)
            let desiredMemberOfNames = Set(memberOfEntries.map(\.name))

            // Revoke removed memberships
            for existing in currentMemberOf where !desiredMemberOfNames.contains(existing.roleName) {
                try await pg.client.revokeRole(role: existing.roleName, from: name)
            }

            // Grant new or update existing memberships
            for entry in memberOfEntries {
                let existing = currentMemberOf.first(where: { $0.roleName == entry.name })
                if existing == nil || existing?.adminOption != entry.adminOption || existing?.inheritOption != entry.inheritOption || existing?.setOption != entry.setOption {
                    try await pg.client.grantRole(role: entry.name, to: name, admin: entry.adminOption, inherit: entry.inheritOption, set: entry.setOption)
                }
            }

            // Sync "Members" memberships (only in edit mode)
            if isEditing {
                let currentMembers = try await admin.listMembers(of: name)
                let desiredMemberNames = Set(memberEntries.map(\.name))

                for existing in currentMembers where !desiredMemberNames.contains(existing.memberName) {
                    try await pg.client.revokeRole(role: name, from: existing.memberName)
                }

                for entry in memberEntries {
                    let existing = currentMembers.first(where: { $0.memberName == entry.name })
                    if existing == nil || existing?.adminOption != entry.adminOption || existing?.inheritOption != entry.inheritOption || existing?.setOption != entry.setOption {
                        try await pg.client.grantRole(role: name, to: entry.name, admin: entry.adminOption, inherit: entry.inheritOption, set: entry.setOption)
                    }
                }
            }

            // Save comment
            if isEditing {
                try await admin.setRoleComment(role: name, comment: roleComment.isEmpty ? nil : roleComment)
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

enum PGRolePage: String, Hashable, CaseIterable {
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

struct PGRoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var adminOption: Bool
    var inheritOption: Bool
    var setOption: Bool
}
