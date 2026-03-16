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
    func pgDefPrivPicker(for objType: PostgresObjectType) -> some View {
        let existingGrantees = Set(
            pgDefaultPrivileges
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
            ForEach(pgRoles.filter { !existingGrantees.contains($0) }, id: \.self) { role in
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
    func pgDefPrivRow(entry: PostgresDefaultPrivilege, objType: PostgresObjectType) -> some View {
        let applicablePrivs = Self.privilegesForObjectType[objType] ?? []
        let key = defPrivKey(entry: entry)

        DisclosureGroup(
            isExpanded: Binding(
                get: { pgDefPrivExpanded.contains(key) },
                set: { if $0 { pgDefPrivExpanded.insert(key) } else { pgDefPrivExpanded.remove(key) } }
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
    func pgDefPrivGrid(entry: PostgresDefaultPrivilege, applicablePrivs: [PostgresPrivilege]) -> some View {
        VStack(spacing: 0) {
            // Header
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

    func pgAddDefPrivWithAllPrivs(role: String, objType: PostgresObjectType) {
        let allPrivs = Self.privilegesForObjectType[objType] ?? []
        let grantee = role == "PUBLIC" ? "" : role
        pgDefaultPrivileges.append(PostgresDefaultPrivilege(
            schema: "public", owner: pgOwner, objectType: objType,
            grantee: grantee,
            privileges: allPrivs.map { PostgresACLPrivilege(privilege: $0) }
        ))
        // Auto-expand the newly added entry
        let key = "\(objType.rawValue):\(grantee):public"
        pgDefPrivExpanded.insert(key)
    }

    func pgToggleDefPriv(entry: PostgresDefaultPrivilege, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgDefPrivIndex(for: entry) else { return }
        var currentPrivs = pgDefaultPrivileges[idx].privileges
        if enabled {
            if !currentPrivs.contains(where: { $0.privilege == privilege }) {
                currentPrivs.append(PostgresACLPrivilege(privilege: privilege))
            }
        } else {
            currentPrivs.removeAll { $0.privilege == privilege }
        }
        if currentPrivs.isEmpty {
            pgDefaultPrivileges.remove(at: idx)
        } else {
            pgDefaultPrivileges[idx] = PostgresDefaultPrivilege(
                schema: entry.schema, owner: entry.owner, objectType: entry.objectType,
                grantee: entry.grantee, privileges: currentPrivs
            )
        }
    }

    func pgToggleDefPrivGrantOption(entry: PostgresDefaultPrivilege, privilege: PostgresPrivilege, enabled: Bool) {
        guard let idx = pgDefPrivIndex(for: entry) else { return }
        var currentPrivs = pgDefaultPrivileges[idx].privileges
        if let privIdx = currentPrivs.firstIndex(where: { $0.privilege == privilege }) {
            currentPrivs[privIdx] = PostgresACLPrivilege(privilege: privilege, withGrantOption: enabled)
            pgDefaultPrivileges[idx] = PostgresDefaultPrivilege(
                schema: entry.schema, owner: entry.owner, objectType: entry.objectType,
                grantee: entry.grantee, privileges: currentPrivs
            )
        }
    }

    func pgRemoveDefaultPrivilege(entry: PostgresDefaultPrivilege) {
        pgDefaultPrivileges.removeAll {
            $0.schema == entry.schema && $0.grantee == entry.grantee
                && $0.objectType == entry.objectType
        }
    }

    private func pgDefPrivIndex(for entry: PostgresDefaultPrivilege) -> Int? {
        pgDefaultPrivileges.firstIndex {
            $0.schema == entry.schema && $0.grantee == entry.grantee && $0.objectType == entry.objectType
        }
    }

    // MARK: - Save (called on Done)

    func pgSaveDefaultPrivilegeChanges() {
        typealias Key = String // "schema:objType:grantee"
        func makeKey(_ e: PostgresDefaultPrivilege) -> Key {
            "\(e.schema):\(e.objectType.rawValue):\(e.grantee)"
        }

        let originalByKey = Dictionary(pgOriginalDefaultPrivileges.map { (makeKey($0), $0) }, uniquingKeysWith: { _, b in b })
        let currentByKey = Dictionary(pgDefaultPrivileges.map { (makeKey($0), $0) }, uniquingKeysWith: { _, b in b })

        let originalKeys = Set(originalByKey.keys)
        let currentKeys = Set(currentByKey.keys)

        // Removed entries — revoke all their privileges
        let removedKeys = originalKeys.subtracting(currentKeys)
        // Added entries — grant all their privileges
        let addedKeys = currentKeys.subtracting(originalKeys)
        // Potentially changed entries
        let commonKeys = originalKeys.intersection(currentKeys)

        var changeCount = 0
        var grantOps: [(schema: String, privs: [PostgresPrivilege], objType: PostgresObjectType, to: String, withGrant: Bool)] = []
        var revokeOps: [(schema: String, privs: [PostgresPrivilege], objType: PostgresObjectType, from: String)] = []

        for key in removedKeys {
            if let orig = originalByKey[key] {
                let schema = orig.schema.isEmpty ? "public" : orig.schema
                let grantee = orig.grantee.isEmpty ? "PUBLIC" : orig.grantee
                revokeOps.append((schema, orig.privileges.map(\.privilege), orig.objectType, grantee))
                changeCount += 1
            }
        }

        for key in addedKeys {
            if let cur = currentByKey[key] {
                let schema = cur.schema.isEmpty ? "public" : cur.schema
                let grantee = cur.grantee.isEmpty ? "PUBLIC" : cur.grantee
                grantOps.append((schema, cur.privileges.map(\.privilege), cur.objectType, grantee, false))
                changeCount += 1
            }
        }

        for key in commonKeys {
            guard let orig = originalByKey[key], let cur = currentByKey[key] else { continue }
            let origPrivs = Set(orig.privileges.map(\.privilege))
            let curPrivs = Set(cur.privileges.map(\.privilege))
            let schema = cur.schema.isEmpty ? "public" : cur.schema
            let grantee = cur.grantee.isEmpty ? "PUBLIC" : cur.grantee

            let added = curPrivs.subtracting(origPrivs)
            let removed = origPrivs.subtracting(curPrivs)

            if !added.isEmpty {
                grantOps.append((schema, Array(added), cur.objectType, grantee, false))
                changeCount += 1
            }
            if !removed.isEmpty {
                revokeOps.append((schema, Array(removed), cur.objectType, grantee))
                changeCount += 1
            }
        }

        guard changeCount > 0 else { return }

        let revokeList = revokeOps
        let grantList = grantOps

        applyPgAlter(message: "Default privileges updated (\(changeCount) change\(changeCount == 1 ? "" : "s")).") { client in
            for op in revokeList {
                try await client.security.revokeDefaultPrivileges(
                    schema: op.schema, revoke: op.privs, onObjectType: op.objType, from: op.from
                )
            }
            for op in grantList {
                try await client.security.alterDefaultPrivileges(
                    schema: op.schema, grant: op.privs, onObjectType: op.objType, to: op.to
                )
            }
        }

        pgOriginalDefaultPrivileges = pgDefaultPrivileges
    }
}
