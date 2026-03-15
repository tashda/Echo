import SwiftUI
import SQLServerKit

struct SecurityLoginSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing an existing login; nil for create mode.
    let existingLoginName: String?
    let onComplete: () -> Void

    @State var selectedPage: LoginPage = .general

    @State var loginName = ""
    @State var authType: AuthType = .sql
    @State var password = ""
    @State var confirmPassword = ""
    @State var defaultDatabase = "master"
    @State var defaultLanguage = ""
    @State var enforcePasswordPolicy = true
    @State var enforcePasswordExpiration = false
    @State var loginEnabled = true

    // Server Roles
    @State var availableServerRoles: [RoleEntry] = []
    @State var loadingRoles = false

    // Database Mapping
    @State var databaseMappings: [LoginDatabaseMapping] = []
    @State var loadingMappings = false
    @State var availableDatabases: [String] = ["master"]
    @State var newMappingDatabase = ""
    @State var newMappingUser = ""

    // Database mapping SSMS-style
    @State var databaseMappingEntries: [DatabaseMappingEntry] = []
    @State var selectedMappingDatabase: String?
    @State var databaseRoleMemberships: [DatabaseRoleMembershipEntry] = []
    @State var loadingDatabaseRoles = false

    @State var errorMessage: String?
    @State var isSubmitting = false
    @State var isLoading = true

    var isEditing: Bool { existingLoginName != nil }

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
                        .foregroundStyle(ColorTokens.Text.secondary)
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
                                    .foregroundStyle(ColorTokens.Text.tertiary)
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
                        .foregroundStyle(ColorTokens.Text.secondary)
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
                            .foregroundStyle(entry.isMapped ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Default Schema") { entry in
                        Text(entry.defaultSchema ?? "dbo")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.secondary)
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
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    } else if databaseRoleMemberships.isEmpty {
                        Text("No fixed database roles available.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
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
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    func mappingToggleBinding(for database: String) -> Binding<Bool> {
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
}

// MARK: - Supporting Types

enum LoginPage: String, Hashable {
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

enum AuthType: Hashable {
    case sql
    case windows
}

struct RoleEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
}

struct DatabaseMappingEntry: Identifiable, Hashable {
    var id: String { databaseName }
    let databaseName: String
    var isMapped: Bool
    var userName: String?
    var defaultSchema: String?
}

struct DatabaseRoleMembershipEntry: Identifiable, Hashable {
    var id: String { roleName }
    let roleName: String
    var isMember: Bool
}
