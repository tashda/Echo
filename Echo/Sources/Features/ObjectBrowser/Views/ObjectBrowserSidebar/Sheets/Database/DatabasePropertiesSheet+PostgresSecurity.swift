import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Security Page

extension DatabasePropertiesSheet {

    /// Database-level privilege names applicable to databases.
    static let databasePrivileges: [PostgresPrivilege] = [.connect, .create, .temporary]

    @ViewBuilder
    func postgresSecurityPage() -> some View {
        Section("Database Privileges") {
            if pgACLEntries.isEmpty {
                Text("No explicit privileges configured.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            }

            ForEach(Array(pgACLEntries.enumerated()), id: \.offset) { index, entry in
                pgACLRow(index: index, entry: entry)
            }
        }

        Section("Grant Privilege") {
            Picker("Role", selection: $pgNewGrantee) {
                Text("Select role\u{2026}").tag("")
                Text("PUBLIC").tag("PUBLIC")
                ForEach(pgRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }

            if !pgNewGrantee.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Privileges")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)

                    HStack(spacing: SpacingTokens.md) {
                        ForEach(Self.databasePrivileges, id: \.rawValue) { priv in
                            Toggle(priv.rawValue, isOn: Binding(
                                get: { pgNewPrivileges.contains(priv) },
                                set: { if $0 { pgNewPrivileges.insert(priv) } else { pgNewPrivileges.remove(priv) } }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                Button("Grant") {
                    pgGrantPrivilege()
                }
                .disabled(pgNewPrivileges.isEmpty)
            }
        }
    }

    @ViewBuilder
    func pgACLRow(index: Int, entry: PostgresACLEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(entry.grantee.isEmpty ? "PUBLIC" : entry.grantee)
                    .font(TypographyTokens.standard)
                Text("Granted by: \(entry.grantor)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .frame(minWidth: 120, alignment: .leading)

            Spacer()

            HStack(spacing: SpacingTokens.xs) {
                ForEach(entry.privileges, id: \.privilege.rawValue) { aclPriv in
                    HStack(spacing: 2) {
                        Text(aclPriv.privilege.rawValue)
                            .font(TypographyTokens.detail)
                        if aclPriv.withGrantOption {
                            Text("*")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.xxs)
                    .padding(.vertical, 2)
                    .background(ColorTokens.Background.secondary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                }
            }

            Button(role: .destructive) {
                let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
                let privs = entry.privileges.map(\.privilege)
                pgACLEntries.remove(at: index)
                applyPgAlter { client in
                    try await client.security.revokeDatabasePrivileges(
                        privileges: privs, onDatabase: databaseName, from: grantee
                    )
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    func pgGrantPrivilege() {
        let grantee = pgNewGrantee
        let privs = Array(pgNewPrivileges)
        guard !grantee.isEmpty, !privs.isEmpty else { return }

        let aclPrivs = privs.map { PostgresACLPrivilege(privilege: $0) }
        pgACLEntries.append(PostgresACLEntry(
            grantee: grantee == "PUBLIC" ? "" : grantee,
            grantor: pgOwner,
            privileges: aclPrivs
        ))

        pgNewGrantee = ""
        pgNewPrivileges = []

        applyPgAlter { client in
            try await client.security.grantDatabasePrivileges(
                privileges: privs, onDatabase: databaseName, to: grantee
            )
        }
    }
}
