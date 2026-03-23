import Foundation
import SQLServerKit

extension LoginEditorViewModel {

    /// Applies changes to the server without closing. Returns true on success.
    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return false
        }

        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Login name is required"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            isEditing ? "Saving login \(name)" : "Creating login \(name)",
            connectionSessionID: session.id
        )

        do {
            let ssec = mssql.serverSecurity

            if isEditing {
                try await submitAlterLogin(ssec: ssec, name: name)
            } else {
                try await submitCreateLogin(ssec: ssec, name: name)
            }

            if hasLoadedRoles {
                try await syncRoleMemberships(ssec: ssec, loginName: name)
            }

            handle?.succeed()
            isSubmitting = false
            return true
        } catch {
            handle?.fail(error.localizedDescription)
            isSubmitting = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Applies changes and closes the window on success.
    func saveAndClose(session: ConnectionSession) async {
        let success = await apply(session: session)
        if success {
            didComplete = true
        }
    }

    // MARK: - Create

    private func submitCreateLogin(ssec: SQLServerServerSecurityClient, name: String) async throws {
        if authType == .sql {
            try await ssec.createSqlLogin(name: name, password: password, options: .init(
                defaultDatabase: defaultDatabase,
                defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
                checkPolicy: enforcePasswordPolicy,
                checkExpiration: enforcePasswordExpiration
            ))
        } else {
            try await ssec.createWindowsLogin(name: name)
        }

        if !loginEnabled {
            try await ssec.enableLogin(name: name, enabled: false)
        }
    }

    // MARK: - Alter

    private func submitAlterLogin(ssec: SQLServerServerSecurityClient, name: String) async throws {
        if authType == .sql && !password.isEmpty {
            try await ssec.setLoginPassword(name: name, newPassword: password)
        }

        try await ssec.enableLogin(name: name, enabled: loginEnabled)
        try await ssec.alterLogin(name: name, options: .init(
            defaultDatabase: defaultDatabase,
            defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
            checkPolicy: authType == .sql ? enforcePasswordPolicy : nil,
            checkExpiration: authType == .sql ? enforcePasswordExpiration : nil
        ))
    }

    // MARK: - Role Membership Sync

    private func syncRoleMemberships(ssec: SQLServerServerSecurityClient, loginName: String) async throws {
        for role in roleEntries where role.name != "public" {
            if role.isMember && !role.originallyMember {
                try await ssec.addMemberToServerRole(role: role.name, principal: loginName)
            } else if !role.isMember && role.originallyMember {
                try await ssec.removeMemberFromServerRole(role: role.name, principal: loginName)
            }
        }
    }
}
