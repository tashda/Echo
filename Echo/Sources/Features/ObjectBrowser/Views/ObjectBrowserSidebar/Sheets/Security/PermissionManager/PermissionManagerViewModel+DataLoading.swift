import Foundation
import SQLServerKit

extension PermissionManagerViewModel {

    // MARK: - Load Principals

    func loadPrincipals(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isLoadingPrincipals = true

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)

            let users = try await mssql.security.listUsers()
            let roles = try await mssql.security.listRoles()

            var choices: [PrincipalChoice] = []

            for user in users {
                choices.append(PrincipalChoice(
                    name: user.name,
                    type: user.type,
                    isFixed: false
                ))
            }

            for role in roles {
                choices.append(PrincipalChoice(
                    name: role.name,
                    type: role.type,
                    isFixed: role.isFixedRole
                ))
            }

            principals = choices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            isLoadingPrincipals = false

            if let initial = initialPrincipalName,
               principals.contains(where: { $0.name == initial }) {
                selectedPrincipalName = initial
                await loadSecurables(session: session)
            }
        } catch {
            isLoadingPrincipals = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Securables (Existing Permissions)

    func loadSecurables(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession,
              !selectedPrincipalName.isEmpty else { return }

        isLoadingSecurables = true

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)

            let permissions = try await mssql.security.listPermissionsDetailed(principal: selectedPrincipalName)

            var entriesBySecurable: [String: SecurableEntry] = [:]

            for perm in permissions {
                let objectName = perm.objectName ?? "DATABASE"
                let schemaName = perm.schemaName
                let key = "\(perm.classDesc):\(schemaName ?? "").\(objectName)"

                if entriesBySecurable[key] == nil {
                    let ref = SecurableReference(
                        typeName: classDescToTypeName(perm.classDesc),
                        schemaName: schemaName,
                        objectName: objectName,
                        objectKind: classDescToObjectKind(perm.classDesc)
                    )
                    entriesBySecurable[key] = SecurableEntry(
                        id: UUID(),
                        securable: ref,
                        permissions: applicablePermissions(for: perm.classDesc).map { permName in
                            let isThisPerm = permName == perm.permission
                            let isGranted = isThisPerm && (perm.state == "GRANT" || perm.state == "GRANT_WITH_GRANT_OPTION")
                            let withGrant = isThisPerm && perm.state == "GRANT_WITH_GRANT_OPTION"
                            let isDenied = isThisPerm && perm.state == "DENY"
                            return PermissionGridRow(
                                permission: permName,
                                isGranted: isGranted,
                                withGrantOption: withGrant,
                                isDenied: isDenied,
                                originalState: PermissionState(
                                    isGranted: isGranted,
                                    withGrantOption: withGrant,
                                    isDenied: isDenied
                                )
                            )
                        }
                    )
                } else {
                    // Update the existing entry's permission row
                    if var entry = entriesBySecurable[key],
                       let idx = entry.permissions.firstIndex(where: { $0.permission == perm.permission }) {
                        let isGranted = perm.state == "GRANT" || perm.state == "GRANT_WITH_GRANT_OPTION"
                        let withGrant = perm.state == "GRANT_WITH_GRANT_OPTION"
                        let isDenied = perm.state == "DENY"
                        entry.permissions[idx] = PermissionGridRow(
                            permission: perm.permission,
                            isGranted: isGranted,
                            withGrantOption: withGrant,
                            isDenied: isDenied,
                            originalState: PermissionState(
                                isGranted: isGranted,
                                withGrantOption: withGrant,
                                isDenied: isDenied
                            )
                        )
                        entriesBySecurable[key] = entry
                    }
                }
            }

            securableEntries = Array(entriesBySecurable.values)
                .sorted { $0.securable.objectName.localizedCaseInsensitiveCompare($1.securable.objectName) == .orderedAscending }
            hasLoadedSecurables = true
            isLoadingSecurables = false
            takeSnapshot()
        } catch {
            isLoadingSecurables = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Effective Permissions

    func loadEffectivePermissions(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession,
              !selectedPrincipalName.isEmpty else { return }

        isLoadingEffective = true

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)

            let permissions = try await mssql.security.listPermissionsDetailed(principal: selectedPrincipalName)

            effectivePermissions = permissions.map { perm in
                EffectivePermissionRow(
                    permission: perm.permission,
                    securableClass: classDescToTypeName(perm.classDesc),
                    securableName: [perm.schemaName, perm.objectName].compactMap { $0 }.joined(separator: "."),
                    grantor: perm.grantor ?? "\u{2014}",
                    state: perm.state
                )
            }.sorted { $0.permission < $1.permission }

            hasLoadedEffective = true
            isLoadingEffective = false
        } catch {
            isLoadingEffective = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func classDescToTypeName(_ classDesc: String) -> String {
        switch classDesc {
        case "OBJECT_OR_COLUMN": "Object"
        case "SCHEMA": "Schema"
        case "DATABASE": "Database"
        case "TYPE": "Type"
        case "ASSEMBLY": "Assembly"
        default: classDesc.capitalized
        }
    }

    private func classDescToObjectKind(_ classDesc: String) -> ObjectKind? {
        switch classDesc {
        case "OBJECT_OR_COLUMN": .table
        case "SCHEMA": nil
        default: nil
        }
    }

    func applicablePermissions(for classDesc: String) -> [String] {
        switch classDesc {
        case "OBJECT_OR_COLUMN":
            ["SELECT", "INSERT", "UPDATE", "DELETE", "REFERENCES",
             "ALTER", "CONTROL", "TAKE OWNERSHIP", "VIEW DEFINITION",
             "VIEW CHANGE TRACKING", "EXECUTE"]
        case "SCHEMA":
            ["ALTER", "CONTROL", "TAKE OWNERSHIP", "CREATE TABLE",
             "CREATE VIEW", "CREATE PROCEDURE", "CREATE FUNCTION",
             "VIEW DEFINITION"]
        case "DATABASE":
            ["ALTER", "ALTER ANY SCHEMA", "ALTER ANY USER", "ALTER ANY ROLE",
             "BACKUP DATABASE", "BACKUP LOG", "CONNECT", "CONNECT REPLICATION",
             "CONTROL", "CREATE TABLE", "CREATE VIEW", "CREATE PROCEDURE",
             "CREATE FUNCTION", "CREATE SCHEMA", "CREATE ROLE",
             "VIEW DATABASE STATE", "VIEW DEFINITION"]
        case "TYPE":
            ["CONTROL", "EXECUTE", "REFERENCES", "TAKE OWNERSHIP", "VIEW DEFINITION"]
        default:
            ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE",
             "ALTER", "CONTROL", "VIEW DEFINITION"]
        }
    }
}
