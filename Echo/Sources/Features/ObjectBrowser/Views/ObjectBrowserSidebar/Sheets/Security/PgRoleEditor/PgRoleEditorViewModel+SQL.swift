import Foundation
import PostgresKit

extension PgRoleEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "-- Enter a role name first" }

        let quoted = "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""

        if isEditing {
            return generateAlterSQL(quoted: quoted)
        } else {
            return generateCreateSQL(quoted: quoted)
        }
    }

    private func generateCreateSQL(quoted: String) -> String {
        var attrs: [String] = []

        if isSuperuser { attrs.append("SUPERUSER") } else { attrs.append("NOSUPERUSER") }
        if canCreateDB { attrs.append("CREATEDB") } else { attrs.append("NOCREATEDB") }
        if canCreateRole { attrs.append("CREATEROLE") } else { attrs.append("NOCREATEROLE") }
        if canLogin { attrs.append("LOGIN") } else { attrs.append("NOLOGIN") }
        if inherit { attrs.append("INHERIT") } else { attrs.append("NOINHERIT") }
        if isReplication { attrs.append("REPLICATION") } else { attrs.append("NOREPLICATION") }
        if bypassRLS { attrs.append("BYPASSRLS") } else { attrs.append("NOBYPASSRLS") }

        if !password.isEmpty {
            attrs.append("ENCRYPTED PASSWORD '\(password)'")
        }

        if let limit = Int(connectionLimit), limit != -1 {
            attrs.append("CONNECTION LIMIT \(limit)")
        }

        if hasExpiration {
            let ts = Self.pgTimestampFormatter.string(from: validUntil)
            attrs.append("VALID UNTIL '\(ts)'")
        }

        var sql = "CREATE ROLE \(quoted) WITH \(attrs.joined(separator: " "));"

        // Membership grants
        for entry in memberOf {
            let roleQuoted = "\"\(entry.roleName.replacingOccurrences(of: "\"", with: "\"\""))\""
            sql += "\nGRANT \(roleQuoted) TO \(quoted)"
            if entry.adminOption { sql += " WITH ADMIN OPTION" }
            sql += ";"
        }

        return sql
    }

    private func generateAlterSQL(quoted: String) -> String {
        var attrs: [String] = []

        if isSuperuser { attrs.append("SUPERUSER") } else { attrs.append("NOSUPERUSER") }
        if canCreateDB { attrs.append("CREATEDB") } else { attrs.append("NOCREATEDB") }
        if canCreateRole { attrs.append("CREATEROLE") } else { attrs.append("NOCREATEROLE") }
        if canLogin { attrs.append("LOGIN") } else { attrs.append("NOLOGIN") }
        if inherit { attrs.append("INHERIT") } else { attrs.append("NOINHERIT") }
        if isReplication { attrs.append("REPLICATION") } else { attrs.append("NOREPLICATION") }
        if bypassRLS { attrs.append("BYPASSRLS") } else { attrs.append("NOBYPASSRLS") }

        if !password.isEmpty {
            attrs.append("ENCRYPTED PASSWORD '\(password)'")
        }

        if let limit = Int(connectionLimit), limit != -1 {
            attrs.append("CONNECTION LIMIT \(limit)")
        }

        if hasExpiration {
            let ts = Self.pgTimestampFormatter.string(from: validUntil)
            attrs.append("VALID UNTIL '\(ts)'")
        }

        return "ALTER ROLE \(quoted)\nWITH \(attrs.joined(separator: " "));"
    }

    // MARK: - Apply

    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Not connected to a PostgreSQL instance"
            return false
        }

        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Role name is required"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            isEditing ? "Saving role \(name)" : "Creating role \(name)",
            connectionSessionID: connectionSessionID
        )

        do {
            let sec = pg.client.security
            let validUntilStr = hasExpiration
                ? Self.pgTimestampFormatter.string(from: validUntil)
                : nil
            let connLimit = Int(connectionLimit)

            if isEditing {
                try await sec.alterUser(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    connectionLimit: connLimit,
                    validUntil: validUntilStr
                )
            } else {
                try await sec.createRole(
                    name: name,
                    password: password.isEmpty ? nil : password,
                    superuser: isSuperuser,
                    createDatabase: canCreateDB,
                    createRole: canCreateRole,
                    login: canLogin,
                    inherit: inherit,
                    replication: isReplication,
                    bypassRLS: bypassRLS,
                    connectionLimit: connLimit,
                    validUntil: validUntilStr
                )
            }

            // Sync membership
            try await syncMembership(sec: sec, roleName: name)

            // Save comment (editing only, but also for new roles after creation)
            if !description.isEmpty {
                try await sec.setRoleComment(role: name, comment: description)
            } else if isEditing {
                try await sec.setRoleComment(role: name, comment: nil)
            }

            // Sync parameters (editing only)
            if isEditing {
                try await syncParameters(sec: sec, roleName: name)
            }

            handle?.succeed()
            isSubmitting = false
            takeSnapshot()
            return true
        } catch {
            handle?.fail(error.localizedDescription)
            isSubmitting = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Save and Close

    func saveAndClose(session: ConnectionSession) async {
        let success = await apply(session: session)
        if success {
            didComplete = true
        }
    }

    // MARK: - Membership Sync

    private func syncMembership(
        sec: PostgresSecurityClient,
        roleName: String
    ) async throws {
        // Sync "Member Of"
        let currentMemberOf = try await sec.listMemberOf(role: roleName)
        let desiredMemberOfNames = Set(memberOf.map(\.roleName))

        for existing in currentMemberOf where !desiredMemberOfNames.contains(existing.roleName) {
            try await sec.revokeRole(role: existing.roleName, from: roleName)
        }

        for entry in memberOf {
            let existing = currentMemberOf.first(where: { $0.roleName == entry.roleName })
            let needsUpdate = existing == nil
                || existing?.adminOption != entry.adminOption
            if needsUpdate {
                try await sec.grantRole(
                    role: entry.roleName,
                    to: roleName,
                    admin: entry.adminOption
                )
            }
        }

        // Sync "Members" (only relevant for editing)
        guard isEditing else { return }

        let currentMembers = try await sec.listMembers(of: roleName)
        let desiredMemberNames = Set(members.map(\.roleName))

        for existing in currentMembers where !desiredMemberNames.contains(existing.memberName) {
            try await sec.revokeRole(role: roleName, from: existing.memberName)
        }

        for entry in members {
            let existing = currentMembers.first(where: { $0.memberName == entry.roleName })
            let needsUpdate = existing == nil
                || existing?.adminOption != entry.adminOption
            if needsUpdate {
                try await sec.grantRole(
                    role: roleName,
                    to: entry.roleName,
                    admin: entry.adminOption
                )
            }
        }
    }

    // MARK: - Parameter Sync

    private func syncParameters(
        sec: PostgresSecurityClient,
        roleName: String
    ) async throws {
        // Apply the explicit parameter list currently configured in the editor.
        for param in roleParameters {
            try await sec.alterRoleSet(
                role: roleName,
                parameter: param.name,
                value: param.value
            )
        }
    }
}
