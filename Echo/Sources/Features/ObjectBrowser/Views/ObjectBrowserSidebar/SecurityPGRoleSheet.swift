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
    @State var validUntilDate: Date = Date()
    @State var hasExpiry = false

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
    @State var settingDefinitions: [PostgresSettingDefinition] = []

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
            var p: [PGRolePage] = [.general, .privileges, .membership]
            if showParametersInCreateMode { p.append(.parameters) }
            return p
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
        .background(ColorTokens.Background.secondary.opacity(0.3))
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
                .foregroundStyle(ColorTokens.Text.secondary)
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

    /// Formats a Date as a PostgreSQL-compatible timestamp string (e.g. "2026-03-10 14:30:00+00").
    static let pgTimestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ssxx"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt
    }()

    /// Parses a PostgreSQL timestamp string back to a Date.
    static func parsePGTimestamp(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd HH:mm:ssxx",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let fmt = DateFormatter()
            fmt.dateFormat = format
            fmt.timeZone = TimeZone(identifier: "UTC")
            if let date = fmt.date(from: string) { return date }
        }
        return nil
    }

    var availableParameters: [PostgresSettingDefinition] {
        let existing = Set(roleParameters.map(\.name))
        return settingDefinitions.filter { !existing.contains($0.name) }
    }

    /// Look up the setting definition for a given parameter name.
    func settingDefinition(for name: String) -> PostgresSettingDefinition? {
        settingDefinitions.first(where: { $0.name == name })
    }

    func addParameter() {
        let value = newParamValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newParamName.isEmpty, !value.isEmpty else { return }
        roleParameters.append(PostgresDatabaseParameter(name: newParamName, value: value))
        newParamName = ""
        newParamValue = ""
    }

    /// Makes parameters page available in create mode too (not just edit).
    var showParametersInCreateMode: Bool { !settingDefinitions.isEmpty }

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
