import Foundation
import SQLServerKit

extension RoleEditorViewModel {

    // MARK: - General Page

    func loadGeneralData(session: ConnectionSession) async {
        isLoadingGeneral = true
        defer {
            isLoadingGeneral = false
            takeSnapshot()
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        // Load available owners (users + roles that can own roles)
        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let users = try await mssql.security.listUsers()
            availableOwners = users.map(\.name).sorted()
        } catch { }

        // If editing, load existing role properties
        if let existingName = existingRoleName {
            do {
                _ = try? await session.session.sessionForDatabase(databaseName)
                let roles = try await mssql.security.listRoles()
                if let role = roles.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    roleName = role.name
                    // Resolve owner principal ID to name
                    if let ownerID = role.ownerPrincipalId {
                        let users = try await mssql.security.listUsers()
                        if let ownerUser = users.first(where: { $0.principalId == ownerID }) {
                            owner = ownerUser.name
                        } else {
                            // Could be a role that owns this role
                            if let ownerRole = roles.first(where: { $0.principalId == ownerID }) {
                                owner = ownerRole.name
                            }
                        }
                    }
                }
            } catch { }
        }
    }

    // MARK: - Members

    func loadMembers(session: ConnectionSession) async {
        isLoadingMembers = true
        defer {
            isLoadingMembers = false
            hasLoadedMembers = true
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let users = try await mssql.security.listUsers()
            let roles = try await mssql.security.listRoles()

            // Combine users and roles as potential members
            var allPrincipals: [String] = users.map(\.name)
            allPrincipals.append(contentsOf: roles.map(\.name))
            // Remove this role from potential members
            let selfName = existingRoleName ?? roleName
            allPrincipals = allPrincipals.filter {
                $0.caseInsensitiveCompare(selfName) != .orderedSame
            }
            allPrincipals.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            // Get current members if editing
            var currentMembers: [String] = []
            if let existingName = existingRoleName {
                currentMembers = try await mssql.security.listRoleMembers(role: existingName)
            }

            var entries = allPrincipals.map { principal in
                let isMember = currentMembers.contains {
                    $0.caseInsensitiveCompare(principal) == .orderedSame
                }
                return RoleMemberEntry(
                    name: principal,
                    isMember: isMember,
                    originallyMember: isMember
                )
            }

            // Sort: members first, then alphabetical
            entries.sort { a, b in
                if a.isMember != b.isMember { return a.isMember }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            memberEntries = entries
            takeSnapshot()
        } catch { }
    }

    // MARK: - Securables

    func loadSecurables(session: ConnectionSession) async {
        isLoadingSecurables = true
        defer {
            isLoadingSecurables = false
            hasLoadedSecurables = true
        }

        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingRoleName else { return }

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let permissions = try await mssql.security.listPermissionsDetailed(principal: existingName)

            // Group permissions by securable
            var securableMap: [String: SecurableEntry] = [:]

            for perm in permissions {
                let key = "\(perm.classDesc):\(perm.schemaName ?? "").\(perm.objectName ?? "(database)")"

                if securableMap[key] == nil {
                    let ref = SecurableReference(
                        typeName: perm.classDesc,
                        schemaName: perm.schemaName,
                        objectName: perm.objectName ?? databaseName,
                        objectKind: nil
                    )
                    securableMap[key] = SecurableEntry(
                        id: UUID(),
                        securable: ref,
                        permissions: []
                    )
                }

                let state = PermissionState(
                    isGranted: perm.state == "GRANT" || perm.state == "GRANT_WITH_GRANT_OPTION",
                    withGrantOption: perm.state == "GRANT_WITH_GRANT_OPTION",
                    isDenied: perm.state == "DENY"
                )

                let row = PermissionGridRow(
                    permission: perm.permission,
                    isGranted: state.isGranted,
                    withGrantOption: state.withGrantOption,
                    isDenied: state.isDenied,
                    originalState: state
                )

                securableMap[key]?.permissions.append(row)
            }

            securableEntries = Array(securableMap.values)
                .sorted { $0.securable.objectName < $1.securable.objectName }
        } catch { }
    }
}
