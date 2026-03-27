import MySQLKit
import SwiftUI

struct MySQLSecurityPrivilegesSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @State private var pendingRevokePrivilege: MySQLPrivilegeGrant?

    var body: some View {
        Table(viewModel.privileges, selection: $viewModel.selectedPrivilegeID) {
            TableColumn("Grantee") { privilege in
                Text(privilege.grantee).font(TypographyTokens.Table.name)
            }.width(min: 180, ideal: 220)

            TableColumn("Schema") { privilege in
                Text(privilege.tableSchema ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(privilege.tableSchema == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }.width(min: 120, ideal: 160)

            TableColumn("Object") { privilege in
                Text(privilege.tableName ?? "*")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(privilege.tableName == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }.width(min: 120, ideal: 160)

            TableColumn("Privilege") { privilege in
                Text(privilege.privilegeType)
                    .font(TypographyTokens.Table.secondaryName)
            }.width(min: 100, ideal: 140)

            TableColumn("Grantable") { privilege in
                Image(systemName: privilege.isGrantable ? "checkmark" : "minus")
                    .foregroundStyle(privilege.isGrantable ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }.width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { _ in
            if let selectedPrivilege = viewModel.privileges.first(where: { viewModel.selectedPrivilegeID.contains($0.id) }) {
                Button(role: .destructive) {
                    pendingRevokePrivilege = selectedPrivilege
                } label: {
                    Label("Revoke Privilege", systemImage: "key.slash")
                }

                Divider()
            }

            Button {
                Task { await viewModel.loadCurrentSection() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .dropConfirmationAlert(
            objectType: "Privilege",
            objectName: Binding(
                get: {
                    pendingRevokePrivilege.map {
                        "\($0.privilegeType) on \($0.tableSchema ?? "schema")/\($0.tableName ?? "*") for \($0.grantee)"
                    }
                },
                set: { newValue in
                    if newValue == nil {
                        pendingRevokePrivilege = nil
                    }
                }
            )
        ) { _ in
            if let privilege = pendingRevokePrivilege {
                Task { await viewModel.revokePrivilege(privilege) }
            }
        }
    }
}
