import SwiftUI
import SQLServerKit

// MARK: - SecurityUserSheet Data Loading & Submit

extension SecurityUserSheet {

    // MARK: - Data Loading

    func loadInitialData() async {
        guard let mssql = session.session as? MSSQLSession else {
            isLoading = false
            return
        }

        // Load available logins
        do {
            let ssec = mssql.serverSecurity
            let logins = try await ssec.listLogins()
            await MainActor.run {
                availableLogins = logins.filter { !$0.isDisabled }.map(\.name).sorted()
            }
        } catch { }

        // Load database roles
        loadingRoles = true
        do {
            let sec = mssql.security
            // Switch to target database
            _ = try? await session.session.sessionForDatabase(databaseName)

            let roles = try await sec.listRoles()
            var entries = roles.map { role in
                RoleMemberEntry(name: role.name, isFixed: role.isFixedRole, isMember: false)
            }

            // If editing, check current memberships
            if let existingName = existingUserName {
                let userRoles = try await sec.listUserRoles(user: existingName)
                for i in entries.indices {
                    if userRoles.contains(where: { $0.caseInsensitiveCompare(entries[i].name) == .orderedSame }) {
                        entries[i].isMember = true
                    }
                }
            }

            entries.sort { a, b in
                if a.isMember != b.isMember { return a.isMember }
                return a.name < b.name
            }

            await MainActor.run {
                availableRoles = entries
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        // If editing, load existing user properties
        if let existingName = existingUserName {
            do {
                let sec = mssql.security
                let users = try await sec.listUsers()
                if let user = users.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    await MainActor.run {
                        userName = user.name
                        defaultSchema = user.defaultSchema ?? "dbo"
                    }
                }
            } catch { }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Submit

    func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "User name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let sec = mssql.security
            // Switch to target database
            _ = try? await session.session.sessionForDatabase(databaseName)

            if isEditing {
                try await sec.alterUser(
                    name: name,
                    defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema
                )
            } else {
                let login = userType == .mappedToLogin ? loginName : nil
                try await sec.createUser(
                    name: name,
                    login: login,
                    options: .init(defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema)
                )
            }

            // Sync role memberships
            for role in availableRoles where role.name != "public" {
                let currentMembers = try await sec.listRoleMembers(role: role.name)
                let isCurrentlyMember = currentMembers.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })

                if role.isMember && !isCurrentlyMember {
                    try await sec.addUserToRole(user: name, role: role.name)
                } else if !role.isMember && isCurrentlyMember {
                    try await sec.removeUserFromRole(user: name, role: role.name)
                }
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

// MARK: - Supporting Types

enum UserPage: String, Hashable {
    case general
    case membership

    var title: String {
        switch self {
        case .general: "General"
        case .membership: "Membership"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.fill"
        case .membership: "person.2"
        }
    }
}

enum UserTypeChoice: Hashable {
    case mappedToLogin
    case withoutLogin
}

struct RoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
}
