import Foundation
import MySQLKit
import SwiftUI

extension MySQLSecurityPrivilegesSection {
    var filterBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            TextField("", text: $filterText, prompt: Text("Filter privileges, grantees, or schemas"))
                .textFieldStyle(.roundedBorder)

            Picker("Scope", selection: $filterScope) {
                ForEach(FilterScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .padding(SpacingTokens.md)
    }

    var privilegeDetailPanel: some View {
        Group {
            if let selectedPrivilege {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            Text(selectedPrivilege.privilegeType)
                                .font(TypographyTokens.prominent.weight(.semibold))
                            Text(selectedPrivilege.grantee)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }

                        Spacer()

                        HStack(spacing: SpacingTokens.sm) {
                            Button("Script GRANT") {
                                openScriptTab(sql: grantSQL(for: selectedPrivilege))
                            }
                            .buttonStyle(.bordered)

                            Button("Script REVOKE") {
                                openScriptTab(sql: revokeSQL(for: selectedPrivilege))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Group {
                        privilegeDetailRow(title: "Scope", value: scopeLabel(for: selectedPrivilege))
                        privilegeDetailRow(title: "Schema", value: selectedPrivilege.tableSchema ?? "All Schemas")
                        privilegeDetailRow(title: "Object", value: selectedPrivilege.tableName ?? "All Objects")
                        privilegeDetailRow(title: "Grant Option", value: selectedPrivilege.isGrantable ? "Allowed" : "No")
                        privilegeDetailRow(title: "Grantee Type", value: granteeType(for: selectedPrivilege).rawValue.capitalized)
                    }

                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Generated REVOKE")
                            .font(TypographyTokens.formLabel)
                        Text(revokeSQL(for: selectedPrivilege))
                            .font(TypographyTokens.monospaced)
                            .textSelection(.enabled)
                            .padding(SpacingTokens.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTokens.Background.secondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(SpacingTokens.md)
            } else {
                ContentUnavailableView {
                    Label("No Privilege Selected", systemImage: "key")
                } description: {
                    Text("Select a privilege grant to inspect its scope and generate GRANT or REVOKE SQL.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SpacingTokens.lg)
            }
        }
    }

    var filteredPrivileges: [MySQLPrivilegeGrant] {
        let normalizedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return viewModel.privileges.filter { privilege in
            let granteeKind = granteeType(for: privilege)
            let matchesScope: Bool
            switch filterScope {
            case .all:
                matchesScope = true
            case .users:
                matchesScope = granteeKind == .user
            case .roles:
                matchesScope = granteeKind == .role
            case .grantable:
                matchesScope = privilege.isGrantable
            }

            guard matchesScope else { return false }
            guard !normalizedFilter.isEmpty else { return true }

            let haystack = [
                privilege.grantee,
                privilege.tableSchema ?? "",
                privilege.tableName ?? "",
                privilege.privilegeType
            ]
            .joined(separator: " ")
            .lowercased()

            return haystack.contains(normalizedFilter)
        }
    }

    var selectedPrivilege: MySQLPrivilegeGrant? {
        filteredPrivileges.first { viewModel.selectedPrivilegeID.contains($0.id) }
            ?? viewModel.privileges.first { viewModel.selectedPrivilegeID.contains($0.id) }
    }

    func privilegeDetailRow(title: String, value: String) -> some View {
        PropertyRow(title: title) {
            Text(value)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .textSelection(.enabled)
        }
    }

    func scopeLabel(for privilege: MySQLPrivilegeGrant) -> String {
        if privilege.tableSchema == nil {
            return "Global"
        }
        if privilege.tableName == nil {
            return "Schema"
        }
        return "Object"
    }

    func granteeType(for privilege: MySQLPrivilegeGrant) -> MySQLPrivilegeGrantee.Kind {
        guard let parsedGrantee = privilege.parsedGrantee else { return .user }
        if viewModel.roles.contains(where: { $0.name == parsedGrantee.username && $0.host == parsedGrantee.host }) {
            return .role
        }
        return .user
    }

    func objectClause(for privilege: MySQLPrivilegeGrant) -> String {
        guard let schema = privilege.tableSchema, !schema.isEmpty else { return "*.*" }
        let escapedSchema = schema.replacingOccurrences(of: "`", with: "``")
        if let table = privilege.tableName, !table.isEmpty {
            let escapedTable = table.replacingOccurrences(of: "`", with: "``")
            return "`\(escapedSchema)`.`\(escapedTable)`"
        }
        return "`\(escapedSchema)`.*"
    }

    func grantSQL(for privilege: MySQLPrivilegeGrant) -> String {
        let suffix = privilege.isGrantable ? " WITH GRANT OPTION" : ""
        return "GRANT \(privilege.privilegeType) ON \(objectClause(for: privilege)) TO \(privilege.grantee)\(suffix);"
    }

    func revokeSQL(for privilege: MySQLPrivilegeGrant) -> String {
        "REVOKE \(privilege.privilegeType) ON \(objectClause(for: privilege)) FROM \(privilege.grantee);"
    }

    func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
