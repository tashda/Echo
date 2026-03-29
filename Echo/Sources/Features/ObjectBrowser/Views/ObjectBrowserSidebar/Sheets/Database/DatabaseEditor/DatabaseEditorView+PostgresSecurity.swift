import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Security Page

extension DatabaseEditorView {

    /// Database-level privileges.
    static var databasePrivileges: [PostgresPrivilege] { [.all, .create, .temporary, .connect] }

    @ViewBuilder
    func postgresSecurityPage() -> some View {
        Section {
            pgSecurityPicker

            ForEach(Array(viewModel.pgACLEntries.enumerated()), id: \.offset) { _, entry in
                pgSecurityRow(entry: entry)
            }
        } header: {
            HStack {
                Text("Privileges")
                Spacer()
                let count = viewModel.pgACLEntries.count
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
    private var pgSecurityPicker: some View {
        let existingGrantees = Set(viewModel.pgACLEntries.map(\.grantee))

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
            ForEach(viewModel.pgRoles.filter { !existingGrantees.contains($0) }, id: \.self) { role in
                Text(role).tag(role)
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func pgSecurityRow(entry: PostgresACLEntry) -> some View {
        let key = entry.grantee.isEmpty ? "__PUBLIC__" : entry.grantee

        DisclosureGroup(
            isExpanded: Binding(
                get: { viewModel.pgACLExpanded.contains(key) },
                set: { if $0 { viewModel.pgACLExpanded.insert(key) } else { viewModel.pgACLExpanded.remove(key) } }
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
    private func pgSecurityGrid(entry: PostgresACLEntry) -> some View {
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

    // MARK: - Actions

    private func pgAddSecurityEntry(role: String) {
        let dbName = viewModel.databaseName
        let grantee = role == "PUBLIC" ? "" : role
        let allPrivs = Self.databasePrivileges.filter { $0 != .all }
        viewModel.pgACLEntries.append(PostgresACLEntry(
            grantee: grantee,
            grantor: viewModel.pgOwner,
            privileges: allPrivs.map { PostgresACLPrivilege(privilege: $0) }
        ))
        let key = grantee.isEmpty ? "__PUBLIC__" : grantee
        viewModel.pgACLExpanded.insert(key)

        Task {
            await viewModel.applyPgAlter(session: session, message: "Privileges granted to \(role).") { client in
                try await client.security.grantDatabasePrivileges(
                    privileges: allPrivs, onDatabase: dbName, to: role
                )
            }
        }
    }

    private func pgToggleSecurityPriv(entry: PostgresACLEntry, privilege: PostgresPrivilege, enabled: Bool) {
        let dbName = viewModel.databaseName
        guard let idx = viewModel.pgACLEntries.firstIndex(where: { $0.grantee == entry.grantee }) else { return }
        var currentPrivs = viewModel.pgACLEntries[idx].privileges

        if enabled {
            if !currentPrivs.contains(where: { $0.privilege == privilege }) {
                currentPrivs.append(PostgresACLPrivilege(privilege: privilege))
            }
        } else {
            currentPrivs.removeAll { $0.privilege == privilege }
        }

        if currentPrivs.isEmpty {
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            viewModel.pgACLEntries.remove(at: idx)
            Task {
                await viewModel.applyPgAlter(session: session, message: "All privileges revoked from \(grantee).") { client in
                    try await client.security.revokeDatabasePrivileges(
                        privileges: [.all], onDatabase: dbName, from: grantee
                    )
                }
            }
        } else {
            viewModel.pgACLEntries[idx] = PostgresACLEntry(
                grantee: entry.grantee, grantor: entry.grantor, privileges: currentPrivs
            )
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            if enabled {
                Task {
                    await viewModel.applyPgAlter(session: session, message: "\(privilege.rawValue) granted to \(grantee).") { client in
                        try await client.security.grantDatabasePrivileges(
                            privileges: [privilege], onDatabase: dbName, to: grantee
                        )
                    }
                }
            } else {
                Task {
                    await viewModel.applyPgAlter(session: session, message: "\(privilege.rawValue) revoked from \(grantee).") { client in
                        try await client.security.revokeDatabasePrivileges(
                            privileges: [privilege], onDatabase: dbName, from: grantee
                        )
                    }
                }
            }
        }
    }

    private func pgToggleSecurityGrantOption(entry: PostgresACLEntry, privilege: PostgresPrivilege, enabled: Bool) {
        let dbName = viewModel.databaseName
        guard let idx = viewModel.pgACLEntries.firstIndex(where: { $0.grantee == entry.grantee }) else { return }
        var currentPrivs = viewModel.pgACLEntries[idx].privileges
        if let privIdx = currentPrivs.firstIndex(where: { $0.privilege == privilege }) {
            currentPrivs[privIdx] = PostgresACLPrivilege(privilege: privilege, withGrantOption: enabled)
            viewModel.pgACLEntries[idx] = PostgresACLEntry(
                grantee: entry.grantee, grantor: entry.grantor, privileges: currentPrivs
            )
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
            if enabled {
                Task {
                    await viewModel.applyPgAlter(session: session, message: "Grant option added for \(privilege.rawValue) to \(grantee).") { client in
                        try await client.security.grantDatabasePrivileges(
                            privileges: [privilege], onDatabase: dbName, to: grantee, withGrantOption: true
                        )
                    }
                }
            } else {
                Task {
                    await viewModel.applyPgAlter(session: session, message: "Grant option removed for \(privilege.rawValue) from \(grantee).") { client in
                        try await client.security.revokeDatabasePrivileges(
                            privileges: [privilege], onDatabase: dbName, from: grantee
                        )
                        try await client.security.grantDatabasePrivileges(
                            privileges: [privilege], onDatabase: dbName, to: grantee
                        )
                    }
                }
            }
        }
    }

    private func pgRemoveSecurityEntry(entry: PostgresACLEntry) {
        let dbName = viewModel.databaseName
        let grantee = entry.grantee.isEmpty ? "PUBLIC" : entry.grantee
        let privs = entry.privileges.map(\.privilege)
        viewModel.pgACLEntries.removeAll { $0.grantee == entry.grantee }
        Task {
            await viewModel.applyPgAlter(session: session, message: "All privileges revoked from \(grantee).") { client in
                try await client.security.revokeDatabasePrivileges(
                    privileges: privs, onDatabase: dbName, from: grantee
                )
            }
        }
    }
}
