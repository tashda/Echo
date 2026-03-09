import SwiftUI
import PostgresKit

struct SecurityPGRoleSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing; nil for create mode.
    let existingRoleName: String?
    let onComplete: () -> Void

    @State private var roleName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var canLogin = true
    @State private var isSuperuser = false
    @State private var canCreateDB = false
    @State private var canCreateRole = false
    @State private var inherit = true
    @State private var isReplication = false
    @State private var connectionLimit = -1
    @State private var validUntil = ""

    // Membership
    @State private var availableRoles: [PGRoleMemberEntry] = []
    @State private var loadingRoles = false

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var selectedTab = 0

    private var isEditing: Bool { existingRoleName != nil }

    private var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && !password.isEmpty && password != confirmPassword { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "person.circle") }
                    .tag(0)
                privilegesTab
                    .tabItem { Label("Privileges", systemImage: "lock.shield") }
                    .tag(1)
                membershipTab
                    .tabItem { Label("Membership", systemImage: "person.2") }
                    .tag(2)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 480, minHeight: 440)
        .onAppear { loadInitialData() }
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
        .padding(SpacingTokens.md2)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
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
                HStack {
                    Text("Connection limit")
                    Spacer()
                    TextField("", value: $connectionLimit, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text(connectionLimit == -1 ? "(unlimited)" : "")
                        .font(TypographyTokens.label)
                        .foregroundStyle(.tertiary)
                }
            }

            if !validUntil.isEmpty || !isEditing {
                Section("Expiration") {
                    TextField("Valid until", text: $validUntil, prompt: Text("YYYY-MM-DD or empty for no expiry"))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Privileges Tab

    private var privilegesTab: some View {
        Form {
            Section("Role Privileges") {
                Toggle("Superuser", isOn: $isSuperuser)
                Toggle("Create databases", isOn: $canCreateDB)
                Toggle("Create roles", isOn: $canCreateRole)
                Toggle("Inherit privileges", isOn: $inherit)
                Toggle("Replication", isOn: $isReplication)
            }

            Section {
                Text("Superuser grants all privileges and bypasses all permission checks.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Membership Tab

    private var membershipTab: some View {
        Form {
            if loadingRoles {
                Section {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading roles\u{2026}")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if availableRoles.isEmpty {
                Section {
                    Text("No other roles found.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Member Of") {
                    ForEach($availableRoles) { $role in
                        Toggle(isOn: $role.isMember) {
                            Text(role.name)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        guard let pg = session.session as? PostgresSession else { return }

        Task {
            // Load available roles for membership
            loadingRoles = true
            do {
                let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
                let roles = try await admin.listRoles()
                let currentName = existingRoleName ?? ""

                var entries = roles
                    .filter { $0.name != currentName }
                    .map { PGRoleMemberEntry(name: $0.name, isMember: false) }

                // Check current memberships if editing
                if !currentName.isEmpty {
                    let memberships = try await admin.listRoleMemberships(role: currentName)
                    for i in entries.indices {
                        if memberships.contains(where: { $0.roleName == entries[i].name && $0.memberName == currentName }) {
                            entries[i].isMember = true
                        }
                    }
                    entries.sort { a, b in
                        if a.isMember != b.isMember { return a.isMember }
                        return a.name < b.name
                    }
                }

                await MainActor.run {
                    availableRoles = entries
                    loadingRoles = false
                }
            } catch {
                await MainActor.run { loadingRoles = false }
            }

            // If editing, load existing role properties
            if let existingName = existingRoleName {
                do {
                    let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
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
                            connectionLimit = role.connectionLimit
                            validUntil = role.validUntil ?? ""
                        }
                    }
                } catch { }
            }
        }
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
                    validUntil: validUntil.isEmpty ? nil : validUntil
                )
            }

            // Sync role memberships
            let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
            let currentMemberships = try await admin.listRoleMemberships(role: name)

            for entry in availableRoles {
                let isCurrentlyMember = currentMemberships.contains(where: {
                    $0.roleName == entry.name && $0.memberName == name
                })

                if entry.isMember && !isCurrentlyMember {
                    try await pg.client.grantRole(role: entry.name, to: name)
                } else if !entry.isMember && isCurrentlyMember {
                    try await pg.client.revokeRole(role: entry.name, from: name)
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

private struct PGRoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var isMember: Bool
}
