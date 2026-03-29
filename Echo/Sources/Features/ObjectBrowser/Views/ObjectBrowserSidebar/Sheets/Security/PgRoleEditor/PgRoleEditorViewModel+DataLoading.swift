import Foundation
import PostgresKit

extension PgRoleEditorViewModel {

    // MARK: - Initial Data Loading

    func loadData(session: ConnectionSession) async {
        isLoading = true
        defer {
            isLoading = false
            takeSnapshot()
        }

        guard let pg = session.session as? PostgresSession else { return }
        let client = pg.client

        // Load available roles for membership pickers
        do {
            let allRoles = try await client.security.listRoles()
            let selfName = existingRoleName ?? ""
            availableRoles = allRoles
                .map(\.name)
                .filter { $0 != selfName }
                .sorted()

            // Load setting definitions for parameters page
            let defs = try await client.security.fetchRoleConfigurableSettings()
            settingDefinitions = defs
        } catch { }

        // Load existing role data when editing
        guard let existingName = existingRoleName else { return }

        do {
            let allRoles = try await client.security.listRoles()
            if let role = allRoles.first(where: { $0.name == existingName }) {
                roleName = role.name
                canLogin = role.canLogin
                isSuperuser = role.isSuperuser
                canCreateDB = role.canCreateDB
                canCreateRole = role.canCreateRole
                inherit = role.inherit
                isReplication = role.isReplication
                bypassRLS = role.bypassRLS
                connectionLimit = "\(role.connectionLimit)"

                if let vu = role.validUntil, !vu.isEmpty,
                   let parsed = Self.parsePGTimestamp(vu) {
                    hasExpiration = true
                    validUntil = parsed
                }

                // Load parameters
                let params = try await client.security.fetchRoleParameters(roleOid: role.oid)
                roleParameters = params.map {
                    PgRoleParameterDraft(name: $0.name, value: $0.value)
                }

                // Load comment
                let comment = try await client.security.fetchRoleComment(role: existingName)
                description = comment ?? ""
            }
        } catch { }

        // Load membership data
        do {
            let moList = try await client.security.listMemberOf(role: existingName)
            memberOf = moList.map {
                PgRoleMembershipDraft(
                    roleName: $0.roleName,
                    adminOption: $0.adminOption,
                    inheritOption: $0.inheritOption,
                    setOption: $0.setOption
                )
            }

            let mList = try await client.security.listMembers(of: existingName)
            members = mList.map {
                PgRoleMembershipDraft(
                    roleName: $0.memberName,
                    adminOption: $0.adminOption,
                    inheritOption: $0.inheritOption,
                    setOption: $0.setOption
                )
            }
        } catch { }
    }

    // MARK: - Timestamp Parsing

    static func parsePGTimestamp(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd HH:mm:ssxx",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let fmt = DateFormatter()
            fmt.dateFormat = format
            fmt.timeZone = TimeZone(identifier: "UTC")
            if let date = fmt.date(from: string) { return date }
        }
        return nil
    }

    static let pgTimestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ssxx"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt
    }()
}
