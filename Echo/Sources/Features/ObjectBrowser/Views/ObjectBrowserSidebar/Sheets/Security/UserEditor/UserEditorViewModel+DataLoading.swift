import Foundation
import SQLServerKit

extension UserEditorViewModel {

    // MARK: - General Page

    func loadGeneralData(session: ConnectionSession) async {
        isLoadingGeneral = true
        defer { isLoadingGeneral = false }

        guard let mssql = session.session as? MSSQLSession else { return }

        // Check containment
        do {
            isDatabaseContained = try await mssql.metadata.isDatabaseContained(database: databaseName)
        } catch { }

        // Load available logins
        do {
            let logins = try await mssql.serverSecurity.listLogins()
            availableLogins = logins.filter { !$0.isDisabled }.map(\.name).sorted()
        } catch { }

        // Load certificates
        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            availableCertificates = try await mssql.security.listCertificates()
        } catch { }

        // Load asymmetric keys
        do {
            availableAsymmetricKeys = try await mssql.security.listAsymmetricKeys()
        } catch { }

        // Load languages
        do {
            availableLanguages = try await mssql.security.listLanguages()
        } catch { }

        // If editing, load existing user properties
        if let existingName = existingUserName {
            do {
                _ = try? await session.session.sessionForDatabase(databaseName)
                let users = try await mssql.security.listUsers()
                if let user = users.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    userName = user.name
                    defaultSchema = user.defaultSchema ?? "dbo"
                    if let login = user.loginName {
                        loginName = login
                    }
                    // Determine user type from authentication type
                    if let authType = user.authenticationType {
                        switch authType {
                        case .database:
                            userType = .withPassword
                        case .windows:
                            userType = .windowsUser
                        case .external, .instance:
                            userType = .mappedToLogin
                        case .none:
                            // .none enum case — no authentication type
                            let typeDesc = user.type.uppercased()
                            if typeDesc.contains("CERTIFICATE") {
                                userType = .mappedToCertificate
                            } else if typeDesc.contains("ASYMMETRIC") {
                                userType = .mappedToAsymmetricKey
                            } else if user.loginName == nil {
                                userType = .withoutLogin
                            } else {
                                userType = .mappedToLogin
                            }
                        }
                    } else {
                        userType = user.loginName != nil ? .mappedToLogin : .withoutLogin
                    }
                }
            } catch { }
        }
    }

    // MARK: - Schemas

    func loadSchemas(session: ConnectionSession) async {
        isLoadingSchemas = true
        defer {
            isLoadingSchemas = false
            hasLoadedSchemas = true
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let schemas = try await mssql.security.listSchemas()
            let targetName = isEditing ? userName : ""

            schemaEntries = schemas.map { schema in
                let isOwned = !targetName.isEmpty &&
                    (schema.owner?.caseInsensitiveCompare(targetName) == .orderedSame)
                return SchemaOwnerEntry(
                    name: schema.name,
                    currentOwner: schema.owner,
                    isOwned: isOwned,
                    originallyOwned: isOwned
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch { }
    }

    // MARK: - Roles

    func loadRoles(session: ConnectionSession) async {
        isLoadingRoles = true
        defer {
            isLoadingRoles = false
            hasLoadedRoles = true
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let roles = try await mssql.security.listRoles()
            var entries = roles.map { role in
                UserEditorRoleMemberEntry(
                    name: role.name,
                    isFixed: role.isFixedRole,
                    isMember: false,
                    originallyMember: false
                )
            }

            // If editing, check current memberships
            if let existingName = existingUserName {
                let userRoles = try await mssql.security.listUserRoles(user: existingName)
                for i in entries.indices {
                    let isMember = userRoles.contains {
                        $0.caseInsensitiveCompare(entries[i].name) == .orderedSame
                    }
                    entries[i] = UserEditorRoleMemberEntry(
                        name: entries[i].name,
                        isFixed: entries[i].isFixed,
                        isMember: isMember,
                        originallyMember: isMember
                    )
                }
            }

            // Sort: members first, then alphabetical
            entries.sort { a, b in
                if a.isMember != b.isMember { return a.isMember }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            roleEntries = entries
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
              let existingName = existingUserName else { return }

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

    // MARK: - Extended Properties

    func loadExtendedProperties(session: ConnectionSession) async {
        isLoadingExtendedProperties = true
        defer {
            isLoadingExtendedProperties = false
            hasLoadedExtendedProperties = true
        }

        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingUserName else { return }

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)
            let props = try await mssql.extendedProperties.listForUser(name: existingName)
            extendedPropertyEntries = props.map { prop in
                ExtendedPropertyEntry(
                    id: UUID(),
                    name: prop.name,
                    value: prop.value,
                    isNew: false,
                    originalName: prop.name,
                    originalValue: prop.value
                )
            }
        } catch { }
    }
}
