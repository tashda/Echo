import SwiftUI
import SQLServerKit

struct SecurityUserSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let databaseName: String
    /// Non-nil when editing; nil for create mode.
    let existingUserName: String?
    let onComplete: () -> Void

    @State private var selectedPage: UserPage = .general

    @State private var userName = ""
    @State private var loginName = ""
    @State private var defaultSchema = "dbo"
    @State private var userType: UserTypeChoice = .mappedToLogin

    // Role Membership
    @State private var availableRoles: [RoleMemberEntry] = []
    @State private var loadingRoles = false

    // Available logins for picker
    @State private var availableLogins: [String] = []

    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isLoading = true

    private var isEditing: Bool { existingUserName != nil }

    private var isFormValid: Bool {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if userType == .mappedToLogin && loginName.isEmpty { return false }
        return true
    }

    private var pages: [UserPage] {
        [.general, .membership]
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
        .frame(minWidth: 640, minHeight: 460)
        .frame(idealWidth: 680, idealHeight: 500)
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
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading user properties\u{2026}")
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
        case .membership:
            membershipPage
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create User") {
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
        Section(isEditing ? "User Properties" : "New Database User") {
            if isEditing {
                LabeledContent("User Name", value: userName)
            } else {
                TextField("User Name", text: $userName)
            }

            if !isEditing {
                Picker("User Type", selection: $userType) {
                    Text("Mapped to Login").tag(UserTypeChoice.mappedToLogin)
                    Text("Without Login").tag(UserTypeChoice.withoutLogin)
                }
            }
        }

        if userType == .mappedToLogin {
            Section("Login Mapping") {
                if availableLogins.isEmpty {
                    TextField("Login Name", text: $loginName)
                } else {
                    Picker("Login Name", selection: $loginName) {
                        Text("Select a login\u{2026}").tag("")
                        ForEach(availableLogins, id: \.self) { login in
                            Text(login).tag(login)
                        }
                    }
                }
            }
        }

        Section("Schema") {
            TextField("Default Schema", text: $defaultSchema, prompt: Text("dbo"))
        }

        Section {
            LabeledContent("Database", value: databaseName)
        }
    }

    // MARK: - Membership Page

    @ViewBuilder
    private var membershipPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Database Role Membership") {
                ForEach($availableRoles) { $role in
                    Toggle(isOn: $role.isMember) {
                        HStack {
                            Text(role.name)
                            if role.isFixed {
                                Text("(fixed)")
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                    }
                    .disabled(role.name == "public")
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        guard let mssql = session.session as? MSSQLSession else {
            isLoading = false
            return
        }

        // Load available logins
        do {
            let ssec = mssql.serverSecurity
            let logins = try await ssec.listLogins()
            await MainActor.run {
                availableLogins = logins.filter { !$0.isDisabled }.map(\.name).sorted()
            }
        } catch { }

        // Load database roles
        loadingRoles = true
        do {
            let sec = mssql.security
            // Switch to target database
            _ = try? await session.session.simpleQuery("USE [\(databaseName)]")

            let roles = try await sec.listRoles()
            var entries = roles.map { role in
                RoleMemberEntry(name: role.name, isFixed: role.isFixedRole, isMember: false)
            }

            // If editing, check current memberships
            if let existingName = existingUserName {
                let userRoles = try await sec.listUserRoles(user: existingName)
                for i in entries.indices {
                    if userRoles.contains(where: { $0.caseInsensitiveCompare(entries[i].name) == .orderedSame }) {
                        entries[i].isMember = true
                    }
                }
            }

            entries.sort { a, b in
                if a.isMember != b.isMember { return a.isMember }
                return a.name < b.name
            }

            await MainActor.run {
                availableRoles = entries
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        // If editing, load existing user properties
        if let existingName = existingUserName {
            do {
                let sec = mssql.security
                let users = try await sec.listUsers()
                if let user = users.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    await MainActor.run {
                        userName = user.name
                        defaultSchema = user.defaultSchema ?? "dbo"
                    }
                }
            } catch { }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Submit

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "User name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let sec = mssql.security
            // Switch to target database
            _ = try? await session.session.simpleQuery("USE [\(databaseName)]")

            if isEditing {
                try await sec.alterUser(
                    name: name,
                    defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema
                )
            } else {
                let login = userType == .mappedToLogin ? loginName : nil
                try await sec.createUser(
                    name: name,
                    login: login,
                    options: .init(defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema)
                )
            }

            // Sync role memberships
            for role in availableRoles where role.name != "public" {
                let currentMembers = try await sec.listRoleMembers(role: role.name)
                let isCurrentlyMember = currentMembers.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })

                if role.isMember && !isCurrentlyMember {
                    try await sec.addUserToRole(user: name, role: role.name)
                } else if !role.isMember && isCurrentlyMember {
                    try await sec.removeUserFromRole(user: name, role: role.name)
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

private enum UserPage: String, Hashable {
    case general
    case membership

    var title: String {
        switch self {
        case .general: "General"
        case .membership: "Membership"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.fill"
        case .membership: "person.2"
        }
    }
}

private enum UserTypeChoice: Hashable {
    case mappedToLogin
    case withoutLogin
}

private struct RoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
}
