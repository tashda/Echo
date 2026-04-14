import MySQLKit
import SwiftUI

struct MySQLSecurityRolesSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState

    @State private var pendingDropRole: String?

    var body: some View {
        VStack(spacing: 0) {
            Table(viewModel.roles, selection: $viewModel.selectedRoleID) {
                TableColumn("Role") { role in
                    Text(role.accountName).font(TypographyTokens.Table.name)
                }.width(min: 180, ideal: 220)

                TableColumn("Members") { role in
                    Text("\(memberCount(for: role))")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 60, ideal: 80)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: String.self) { selection in
                if let role = viewModel.roles.first(where: { selection.contains($0.id) }) {
                    Menu("Script as", systemImage: "scroll") {
                        Button { openScriptTab(sql: "CREATE ROLE \(role.accountName);") } label: {
                            Label("CREATE ROLE", systemImage: "plus.square")
                        }
                        Button { openScriptTab(sql: "DROP ROLE \(role.accountName);") } label: {
                            Label("DROP ROLE", systemImage: "minus.square")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        pendingDropRole = role.accountName
                    } label: {
                        Label("Drop Role", systemImage: "trash")
                    }
                } else {
                    Button {
                        Task { await viewModel.loadCurrentSection() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }

            Divider()

            Table(viewModel.selectedRoleAssignments) {
                TableColumn("Grantee") { assignment in
                    Text(assignment.grantee)
                        .font(TypographyTokens.Table.secondaryName)
                }.width(min: 180, ideal: 220)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .frame(minHeight: 180)
        }
        .dropConfirmationAlert(objectType: "Role", objectName: $pendingDropRole) { _ in
            Task { await viewModel.dropSelectedRole() }
        }
    }

    private func memberCount(for role: MySQLRoleDefinition) -> Int {
        viewModel.roleAssignments.filter { $0.roleName == role.name && $0.roleHost == role.host }.count
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
