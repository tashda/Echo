import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Security Page

extension DatabasePropertiesSheet {

    /// Database-level privileges.
    static let databasePrivileges: [PostgresPrivilege] = [.all, .create, .temporary, .connect]

    @ViewBuilder
    func postgresSecurityPage() -> some View {
        Section {
            pgSecurityPicker

            ForEach(Array(pgACLEntries.enumerated()), id: \.offset) { _, entry in
                pgSecurityRow(entry: entry)
            }
        } header: {
            HStack {
                Text("Privileges")
                Spacer()
                let count = pgACLEntries.count
                if count > 0 {
                    Text("\(count) configured")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
    }

    // MARK: - Add Picker

    @ViewBuilder
    var pgSecurityPicker: some View {
        let existingGrantees = Set(pgACLEntries.map(\.grantee))

        Picker("Add Role", selection: Binding(
            get: { "" },
            set: { role in
                guard !role.isEmpty else { return }
                pgAddSecurityEntry(role: role)
            }
        )) {
            Text("Select role\u{2026}").tag("")
            if !existingGrantees.contains("") {
                Text("PUBLIC").tag("PUBLIC")
            }
            ForEach(pgRoles.filter { !existingGrantees.contains($0) }, id: \.self) { role in
                Text(role).tag(role)
            }
        }
    }

    // MARK: - Row (disclosure style)

    @ViewBuilder
    func pgSecurityRow(entry: PostgresACLEntry) -> some View {
        let key = entry.grantee.isEmpty ? "__PUBLIC__" : entry.grantee

        DisclosureGroup(
            isExpanded: Binding(
                get: { pgACLExpanded.contains(key) },
                set: { if $0 { pgACLExpanded.insert(key) } else { pgACLExpanded.remove(key) } }
            )
        ) {
            pgSecurityGrid(entry: entry)
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Text(entry.grantee.isEmpty ? "PUBLIC" : entry.grantee)
                    .font(TypographyTokens.standard)

                Text("by \(entry.grantor)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                Spacer()

                let activeCount = entry.privileges.count
                Text("\(activeCount)/\(Self.databasePrivileges.count)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                Button(role: .destructive) {
                    pgRemoveSecurityEntry(entry: entry)
                } label: {
                    Image(systemName: "trash")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Privilege Grid

    @ViewBuilder
    func pgSecurityGrid(entry: PostgresACLEntry) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privilege")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Grant Option")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 90, alignment: .leading)
            }
            .padding(.bottom, SpacingTokens.xxs)

            ForEach(Self.databasePrivileges, id: \.rawValue) { priv in
                let aclPriv = entry.privileges.first { $0.privilege == priv }
                let isGranted = aclPriv != nil
                let hasGrantOption = aclPriv?.withGrantOption ?? false

                HStack {
                    Toggle(priv.rawValue, isOn: Binding(
                        get: { isGranted },
                        set: { pgToggleSecurityPriv(entry: entry, privilege: priv, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(TypographyTokens.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: Binding(
                        get: { hasGrantOption },
                        set: { pgToggleSecurityGrantOption(entry: entry, privilege: priv, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(!isGranted)
                    .frame(width: 90, alignment: .leading)
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

    // MARK: - Actions (local only, saved via applyPgAlter on Done for immediate items)

    func pgAddSecurityEntry(role: String) {
        let grantee = role == "PUBLIC" ? "" : role
        // Add with all database privileges by default
        let allPrivs = Self.databasePrivileges.filter { $0 != .all }
        pgACLEntries.append(PostgresACLEntry(
            grantee: grantee,
            grantor: pgOwner,
            privileges: allPrivs.map { PostgresACLPrivilege(privilege: $0) }
        ))
        // Auto-expand
        let key = grantee.isEmpty ? "__PUBLIC__" : grantee
        pgACLExpanded.insert(key)

        // Apply immediately
        applyPgAlter(message: "Privileges granted to \(role).") { client in
            try await client.security.grantDatabasePrivileges(
                privileges: allPrivs, onDatabase: databaseName, to: role
            )
        }
    }

    func pgToggleSecurityPriv(entry: PostgresACLEntry, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgACLEntries.firstIndex(where: { $0.grantee == entry.grantee }) else { return }
        var currentPrivs = pgACLEntries[idx].privileges

        if enabled {
            if !currentPrivs.contains(where: { $0.privilege == privilege }) {
                currentPrivs.append(PostgresACLPrivilege(privilege: privilege))
            }
        } else {
            currentPrivs.removeAll { $0.privilege == privilege }
        }

        if currentPrivs.isEmpty {
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            pgACLEntries.remove(at: idx)
            applyPgAlter(message: "All privileges revoked from \(grantee).") { client in
                try await client.security.revokeDatabasePrivileges(
                    privileges: [.all], onDatabase: databaseName, from: grantee
                )
            }
        } else {
            pgACLEntries[idx] = PostgresACLEntry(
                grantee: entry.grantee, grantor: entry.grantor, privileges: currentPrivs
            )
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            if enabled {
                applyPgAlter(message: "\(privilege.rawValue) granted to \(grantee).") { client in
                    try await client.security.grantDatabasePrivileges(
                        privileges: [privilege], onDatabase: databaseName, to: grantee
                    )
                }
            } else {
                applyPgAlter(message: "\(privilege.rawValue) revoked from \(grantee).") { client in
                    try await client.security.revokeDatabasePrivileges(
                        privileges: [privilege], onDatabase: databaseName, from: grantee
                    )
                }
            }
        }
    }

    func pgToggleSecurityGrantOption(entry: PostgresACLEntry, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgACLEntries.firstIndex(where: { $0.grantee == entry.grantee }) else { return }
        var currentPrivs = pgACLEntries[idx].privileges
        if let privIdx = currentPrivs.firstIndex(where: { $0.privilege == privilege }) {
            currentPrivs[privIdx] = PostgresACLPrivilege(privilege: privilege, withGrantOption: enabled)
            pgACLEntries[idx] = PostgresACLEntry(
                grantee: entry.grantee, grantor: entry.grantor, privileges: currentPrivs
            )
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            if enabled {
                applyPgAlter(message: "Grant option added for \(privilege.rawValue) to \(grantee).") { client in
                    try await client.security.grantDatabasePrivileges(
                        privileges: [privilege], onDatabase: databaseName, to: grantee, withGrantOption: true
                    )
                }
            } else {
                // Revoke grant option only = re-grant without grant option
                applyPgAlter(message: "Grant option removed for \(privilege.rawValue) from \(grantee).") { client in
                    try await client.security.revokeDatabasePrivileges(
                        privileges: [privilege], onDatabase: databaseName, from: grantee
                    )
                    try await client.security.grantDatabasePrivileges(
                        privileges: [privilege], onDatabase: databaseName, to: grantee
                    )
                }
            }
        }
    }

    func pgRemoveSecurityEntry(entry: PostgresACLEntry) {
        let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
        let privs = entry.privileges.map(\.privilege)
        pgACLEntries.removeAll { $0.grantee == entry.grantee }
        applyPgAlter(message: "All privileges revoked from \(grantee).") { client in
            try await client.security.revokeDatabasePrivileges(
                privileges: privs, onDatabase: databaseName, from: grantee
            )
        }
    }
}
