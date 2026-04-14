import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet Helpers & Supporting Types

extension SecurityPGRoleSheet {

    // MARK: - Membership Table

    @ViewBuilder
    func membershipTableContent(
        entries: Binding<[PGRoleMemberEntry]>,
        selection: Binding<Set<String>>,
        availableRoles: [String],
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (Set<String>) -> Void
    ) -> some View {
        Table(entries.wrappedValue, selection: selection) {
            TableColumn("Role") { entry in
                Text(entry.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Admin") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                    Toggle("", isOn: binding.adminOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)

            TableColumn("Inherit") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                    Toggle("", isOn: binding.inheritOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)

            TableColumn("Set") { entry in
                if let binding = entries.first(where: { $0.wrappedValue.name == entry.name }) {
                    Toggle("", isOn: binding.setOption)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }
            .width(min: 40, ideal: 56)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, SpacingTokens.lg)
        .frame(minHeight: 60, maxHeight: 200)

        HStack(spacing: SpacingTokens.none) {
            Menu {
                if availableRoles.isEmpty {
                    Text("No roles available")
                } else {
                    ForEach(availableRoles, id: \.self) { role in
                        Button(role) { onAdd(role) }
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(availableRoles.isEmpty)

            Divider()
                .frame(height: SpacingTokens.sm)

            Button {
                onRemove(selection.wrappedValue)
            } label: {
                Image(systemName: "minus")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(
                        selection.wrappedValue.isEmpty
                            ? ColorTokens.Text.quaternary
                            : ColorTokens.Text.secondary
                    )
                    .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .disabled(selection.wrappedValue.isEmpty)

            Spacer()
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
