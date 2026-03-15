import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Default Privileges Page

extension DatabasePropertiesSheet {

    /// Privileges applicable to each object type for default privileges.
    static let privilegesForObjectType: [PostgresObjectType: [PostgresPrivilege]] = [
        .tables: [.select, .insert, .update, .delete, .truncate, .references, .trigger],
        .sequences: [.select, .update, .usage],
        .functions: [.execute],
        .types: [.usage],
    ]

    @ViewBuilder
    func postgresDefaultPrivilegesPage() -> some View {
        let objectTypes: [PostgresObjectType] = [.tables, .sequences, .functions, .types]

        ForEach(objectTypes, id: \.rawValue) { objType in
            let entries = pgDefaultPrivileges.filter { $0.objectType == objType }
            Section(objType.rawValue.capitalized) {
                if entries.isEmpty {
                    Text("No default privileges for \(objType.rawValue.lowercased()).")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.detail)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        pgDefaultPrivilegeRow(entry: entry)
                    }
                }
            }
        }

        Section("Add Default Privilege") {
            pgDefaultPrivilegeAddControls
        }
    }

    @ViewBuilder
    func pgDefaultPrivilegeRow(entry: PostgresDefaultPrivilege) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(entry.grantee.isEmpty ? "PUBLIC" : entry.grantee)
                    .font(TypographyTokens.standard)
                HStack(spacing: SpacingTokens.xs) {
                    if !entry.schema.isEmpty {
                        Text("Schema: \(entry.schema)")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    Text("Owner: \(entry.owner)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            Spacer()

            HStack(spacing: SpacingTokens.xxs) {
                ForEach(entry.privileges, id: \.privilege.rawValue) { aclPriv in
                    Text(aclPriv.privilege.rawValue)
                        .font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xxs)
                        .padding(.vertical, 2)
                        .background(ColorTokens.Background.secondary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                }
            }

            Button(role: .destructive) {
                pgRevokeDefaultPrivilege(entry: entry)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    var pgDefaultPrivilegeAddControls: some View {
        Picker("Schema", selection: $pgNewDefPrivSchema) {
            Text("All schemas").tag("")
            ForEach(pgSchemas, id: \.self) { schema in
                Text(schema).tag(schema)
            }
        }

        Picker("Object Type", selection: $pgNewDefPrivObjectType) {
            ForEach([PostgresObjectType.tables, .sequences, .functions, .types], id: \.rawValue) { objType in
                Text(objType.rawValue.capitalized).tag(objType)
            }
        }

        Picker("Role", selection: $pgNewDefPrivGrantee) {
            Text("Select role\u{2026}").tag("")
            Text("PUBLIC").tag("PUBLIC")
            ForEach(pgRoles, id: \.self) { role in
                Text(role).tag(role)
            }
        }

        if !pgNewDefPrivGrantee.isEmpty {
            let applicablePrivs = Self.privilegesForObjectType[pgNewDefPrivObjectType] ?? []
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Privileges")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                HStack(spacing: SpacingTokens.md) {
                    ForEach(applicablePrivs, id: \.rawValue) { priv in
                        Toggle(priv.rawValue, isOn: Binding(
                            get: { pgNewDefPrivPrivileges.contains(priv) },
                            set: { if $0 { pgNewDefPrivPrivileges.insert(priv) } else { pgNewDefPrivPrivileges.remove(priv) } }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Button("Add") {
                pgAddDefaultPrivilege()
            }
            .disabled(pgNewDefPrivPrivileges.isEmpty)
        }
    }

    // MARK: - Actions

    func pgAddDefaultPrivilege() {
        let schema = pgNewDefPrivSchema.isEmpty ? "public" : pgNewDefPrivSchema
        let grantee = pgNewDefPrivGrantee
        let objType = pgNewDefPrivObjectType
        let privs = Array(pgNewDefPrivPrivileges)
        guard !grantee.isEmpty, !privs.isEmpty else { return }

        pgDefaultPrivileges.append(PostgresDefaultPrivilege(
            schema: schema, owner: pgOwner, objectType: objType,
            grantee: grantee == "PUBLIC" ? "" : grantee,
            privileges: privs.map { PostgresACLPrivilege(privilege: $0) }
        ))

        pgNewDefPrivGrantee = ""
        pgNewDefPrivPrivileges = []

        applyPgAlter { client in
            try await client.security.alterDefaultPrivileges(
                schema: schema, grant: privs, onObjectType: objType, to: grantee
            )
        }
    }

    func pgRevokeDefaultPrivilege(entry: PostgresDefaultPrivilege) {
        let schema = entry.schema.isEmpty ? "public" : entry.schema
        let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
        let privs = entry.privileges.map(\.privilege)

        pgDefaultPrivileges.removeAll {
            $0.schema == entry.schema && $0.grantee == entry.grantee
                && $0.objectType == entry.objectType
        }

        applyPgAlter { client in
            try await client.security.revokeDefaultPrivileges(
                schema: schema, revoke: privs, onObjectType: entry.objectType, from: grantee
            )
        }
    }
}
