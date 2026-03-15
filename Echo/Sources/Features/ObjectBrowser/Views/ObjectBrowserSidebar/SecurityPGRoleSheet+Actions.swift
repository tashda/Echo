import SwiftUI
import PostgresKit

extension SecurityPGRoleSheet {

    // MARK: - Data Loading

    func loadInitialData() async {
        guard let pg = session.session as? PostgresSession else {
            isLoading = false
            return
        }

        let client = pg.client

        // Fetch configurable settings definitions for the parameters page
        do {
            let defs = try await client.security.fetchRoleConfigurableSettings()
            await MainActor.run { settingDefinitions = defs }
        } catch { }

        loadingRoles = true
        do {
            let roles = try await client.security.listRoles()
            let currentName = existingRoleName ?? ""
            let allRoleNames = roles.map(\.name).filter { $0 != currentName }.sorted()

            var moEntries: [PGRoleMemberEntry] = []
            var mEntries: [PGRoleMemberEntry] = []

            if !currentName.isEmpty {
                let memberOf = try await client.security.listMemberOf(role: currentName)
                moEntries = memberOf.map { m in
                    PGRoleMemberEntry(
                        name: m.roleName,
                        adminOption: m.adminOption,
                        inheritOption: m.inheritOption,
                        setOption: m.setOption
                    )
                }

                let members = try await client.security.listMembers(of: currentName)
                mEntries = members.map { m in
                    PGRoleMemberEntry(
                        name: m.memberName,
                        adminOption: m.adminOption,
                        inheritOption: m.inheritOption,
                        setOption: m.setOption
                    )
                }
            }

            let moNames = Set(moEntries.map(\.name))
            let mNames = Set(mEntries.map(\.name))

            await MainActor.run {
                memberOfEntries = moEntries
                memberEntries = mEntries
                availableRolesForMemberOf = allRoleNames.filter { !moNames.contains($0) }
                availableRolesForMembers = allRoleNames.filter { !mNames.contains($0) }
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        if let existingName = existingRoleName {
            do {
                let roles = try await client.security.listRoles()
                if let role = roles.first(where: { $0.name == existingName }) {
                    await MainActor.run {
                        roleName = role.name
                        canLogin = role.canLogin
                        isSuperuser = role.isSuperuser
                        canCreateDB = role.canCreateDB
                        canCreateRole = role.canCreateRole
                        inherit = role.inherit
                        isReplication = role.isReplication
                        bypassRLS = role.bypassRLS
                        connectionLimit = role.connectionLimit
                        validUntil = role.validUntil ?? ""
                        if let vu = role.validUntil, !vu.isEmpty, let parsed = Self.parsePGTimestamp(vu) {
                            hasExpiry = true
                            validUntilDate = parsed
                        } else {
                            hasExpiry = false
                        }
                    }

                    let params = try await client.security.fetchRoleParameters(roleOid: role.oid)
                    await MainActor.run { roleParameters = params }

                    let labels = try await client.security.fetchRoleSecurityLabels(role: existingName)
                    await MainActor.run { securityLabels = labels }

                    let comment = try await client.security.fetchRoleComment(role: existingName)
                    await MainActor.run { roleComment = comment ?? "" }
                }
            } catch { }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Submit

    func submit() async {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Not connected to a PostgreSQL instance"
            return
        }

        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Role name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            if isEditing {
                try await pg.client.security.alterUser(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    validUntil: validUntil.isEmpty ? nil : validUntil
                )
            } else {
                try await pg.client.security.createUser(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    validUntil: validUntil.isEmpty ? nil : validUntil
                )
            }

            // Sync "Member Of" memberships
            let currentMemberOf = try await pg.client.security.listMemberOf(role: name)
            let desiredMemberOfNames = Set(memberOfEntries.map(\.name))

            // Revoke removed memberships
            for existing in currentMemberOf where !desiredMemberOfNames.contains(existing.roleName) {
                try await pg.client.security.revokeRole(role: existing.roleName, from: name)
            }

            // Grant new or update existing memberships
            for entry in memberOfEntries {
                let existing = currentMemberOf.first(where: { $0.roleName == entry.name })
                if existing == nil || existing?.adminOption != entry.adminOption || existing?.inheritOption != entry.inheritOption || existing?.setOption != entry.setOption {
                    try await pg.client.security.grantRole(role: entry.name, to: name, admin: entry.adminOption, inherit: entry.inheritOption, set: entry.setOption)
                }
            }

            // Sync "Members" memberships (only in edit mode)
            if isEditing {
                let currentMembers = try await pg.client.security.listMembers(of: name)
                let desiredMemberNames = Set(memberEntries.map(\.name))

                for existing in currentMembers where !desiredMemberNames.contains(existing.memberName) {
                    try await pg.client.security.revokeRole(role: name, from: existing.memberName)
                }

                for entry in memberEntries {
                    let existing = currentMembers.first(where: { $0.memberName == entry.name })
                    if existing == nil || existing?.adminOption != entry.adminOption || existing?.inheritOption != entry.inheritOption || existing?.setOption != entry.setOption {
                        try await pg.client.security.grantRole(role: name, to: entry.name, admin: entry.adminOption, inherit: entry.inheritOption, set: entry.setOption)
                    }
                }
            }

            // Save comment
            if isEditing {
                try await pg.client.security.setRoleComment(role: name, comment: roleComment.isEmpty ? nil : roleComment)
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
