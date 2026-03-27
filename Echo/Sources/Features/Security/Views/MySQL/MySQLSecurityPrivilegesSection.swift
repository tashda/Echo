import MySQLKit
import SwiftUI

struct MySQLSecurityPrivilegesSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

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

            TableColumn("Table") { privilege in
                Text(privilege.tableName ?? "\u{2014}")
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
            Button {
                Task { await viewModel.loadCurrentSection() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
}
