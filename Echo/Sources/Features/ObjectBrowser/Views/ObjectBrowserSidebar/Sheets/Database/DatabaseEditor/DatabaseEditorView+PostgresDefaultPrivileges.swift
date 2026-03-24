import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Default Privileges Page

extension DatabaseEditorView {

    /// Privileges applicable to each object type for default privileges.
    static var privilegesForObjectType: [PostgresObjectType: [PostgresPrivilege]] {
        [
            .tables: [.select, .insert, .update, .delete, .truncate, .references, .trigger],
            .sequences: [.select, .update, .usage],
            .functions: [.execute],
            .types: [.usage],
        ]
    }

    @ViewBuilder
    func postgresDefaultPrivilegesPage() -> some View {
        let objectTypes: [PostgresObjectType] = [.tables, .sequences, .functions, .types]

        ForEach(objectTypes, id: \.rawValue) { objType in
            let entries = viewModel.pgDefaultPrivileges.filter { $0.objectType == objType }

            Section {
                pgDefPrivPicker(for: objType)

                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    pgDefPrivRow(entry: entry, objType: objType)
                }
            } header: {
                HStack {
                    Text(objType.rawValue.capitalized)
                    Spacer()
                    let count = entries.count
                    if count > 0 {
                        Text("\(count) configured")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Add Picker

    @ViewBuilder
    private func pgDefPrivPicker(for objType: PostgresObjectType) -> some View {
        let existingGrantees = Set(
            viewModel.pgDefaultPrivileges
                .filter { $0.objectType == objType }
                .map { $0.grantee }
        )

        Picker("Add Role", selection: Binding(
            get: { "" },
            set: { role in
                guard !role.isEmpty else { return }
                pgAddDefPrivWithAllPrivs(role: role, objType: objType)
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

    // MARK: - Disclosure key

    private func defPrivKey(entry: PostgresDefaultPrivilege) -> String {
        "\(entry.objectType.rawValue):\(entry.grantee):\(entry.schema)"
    }

    // MARK: - Row (disclosure style)

    @ViewBuilder
    private func pgDefPrivRow(entry: PostgresDefaultPrivilege, objType: PostgresObjectType) -> some View {
        let applicablePrivs = Self.privilegesForObjectType[objType] ?? []
        let key = defPrivKey(entry: entry)

        DisclosureGroup(
            isExpanded: Binding(
                get: { viewModel.pgDefPrivExpanded.contains(key) },
                set: { if $0 { viewModel.pgDefPrivExpanded.insert(key) } else { viewModel.pgDefPrivExpanded.remove(key) } }
            )
        ) {
            pgDefPrivGrid(entry: entry, applicablePrivs: applicablePrivs)
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Text(entry.grantee.isEmpty ? "PUBLIC" : entry.grantee)
                    .font(TypographyTokens.standard)

                Text("by \(entry.owner)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                Spacer()

                let activeCount = entry.privileges.count
                let totalCount = applicablePrivs.count
                Text("\(activeCount)/\(totalCount)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                Button(role: .destructive) {
                    pgRemoveDefaultPrivilege(entry: entry)
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
    private func pgDefPrivGrid(entry: PostgresDefaultPrivilege, applicablePrivs: [PostgresPrivilege]) -> some View {
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

            ForEach(applicablePrivs, id: \.rawValue) { priv in
                let aclPriv = entry.privileges.first { $0.privilege == priv }
                let isGranted = aclPriv != nil
                let hasGrantOption = aclPriv?.withGrantOption ?? false

                HStack {
                    Toggle(priv.rawValue, isOn: Binding(
                        get: { isGranted },
                        set: { pgToggleDefPriv(entry: entry, privilege: priv, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(TypographyTokens.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("", isOn: Binding(
                        get: { hasGrantOption },
                        set: { pgToggleDefPrivGrantOption(entry: entry, privilege: priv, enabled: $0) }
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

    private func pgAddDefPrivWithAllPrivs(role: String, objType: PostgresObjectType) {
        let allPrivs = Self.privilegesForObjectType[objType] ?? []
        let grantee = role == "PUBLIC" ? "" : role
        viewModel.pgDefaultPrivileges.append(PostgresDefaultPrivilege(
            schema: "public", owner: viewModel.pgOwner, objectType: objType,
            grantee: grantee,
            privileges: allPrivs.map { PostgresACLPrivilege(privilege: $0) }
        ))
        let key = "\(objType.rawValue):\(grantee):public"
        viewModel.pgDefPrivExpanded.insert(key)
    }

    private func pgToggleDefPriv(entry: PostgresDefaultPrivilege, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgDefPrivIndex(for: entry) else { return }
        var currentPrivs = viewModel.pgDefaultPrivileges[idx].privileges
        if enabled {
            if !currentPrivs.contains(where: { $0.privilege == privilege }) {
                currentPrivs.append(PostgresACLPrivilege(privilege: privilege))
            }
        } else {
            currentPrivs.removeAll { $0.privilege == privilege }
        }
        if currentPrivs.isEmpty {
            viewModel.pgDefaultPrivileges.remove(at: idx)
        } else {
            viewModel.pgDefaultPrivileges[idx] = PostgresDefaultPrivilege(
                schema: entry.schema, owner: entry.owner, objectType: entry.objectType,
                grantee: entry.grantee, privileges: currentPrivs
            )
        }
    }

    private func pgToggleDefPrivGrantOption(entry: PostgresDefaultPrivilege, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgDefPrivIndex(for: entry) else { return }
        var currentPrivs = viewModel.pgDefaultPrivileges[idx].privileges
        if let privIdx = currentPrivs.firstIndex(where: { $0.privilege == privilege }) {
            currentPrivs[privIdx] = PostgresACLPrivilege(privilege: privilege, withGrantOption: enabled)
            viewModel.pgDefaultPrivileges[idx] = PostgresDefaultPrivilege(
                schema: entry.schema, owner: entry.owner, objectType: entry.objectType,
                grantee: entry.grantee, privileges: currentPrivs
            )
        }
    }

    private func pgRemoveDefaultPrivilege(entry: PostgresDefaultPrivilege) {
        viewModel.pgDefaultPrivileges.removeAll {
            $0.schema == entry.schema && $0.grantee == entry.grantee
                && $0.objectType == entry.objectType
        }
    }

    private func pgDefPrivIndex(for entry: PostgresDefaultPrivilege) -> Int? {
        viewModel.pgDefaultPrivileges.firstIndex {
            $0.schema == entry.schema && $0.grantee == entry.grantee && $0.objectType == entry.objectType
        }
    }
}
