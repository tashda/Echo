import MySQLKit
import SwiftUI

struct MySQLSecurityUsersSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState

    @State private var pendingDropUser: String?

    var body: some View {
        VStack(spacing: 0) {
            Table(viewModel.users, selection: $viewModel.selectedUserID) {
                TableColumn("Account") { user in
                    Text(user.accountName).font(TypographyTokens.Table.name)
                }.width(min: 180, ideal: 220)

                TableColumn("Plugin") { user in
                    Text(user.authenticationPlugin ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(user.authenticationPlugin == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }.width(min: 100, ideal: 150)

                TableColumn("Locked") { user in
                    Image(systemName: user.accountLocked ? "lock.fill" : "lock.open")
                        .foregroundStyle(user.accountLocked ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                }.width(60)

                TableColumn("Password") { user in
                    Text(user.passwordExpired ? "Expired" : "Valid")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(user.passwordExpired ? ColorTokens.Status.warning : ColorTokens.Status.success)
                }.width(min: 70, ideal: 90)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: String.self) { selection in
                if let user = viewModel.users.first(where: { selection.contains($0.id) }) {
                    Button {
                        Task {
                            if user.accountLocked {
                                await viewModel.unlockSelectedUser()
                            } else {
                                await viewModel.lockSelectedUser()
                            }
                        }
                    } label: {
                        Label(user.accountLocked ? "Unlock User" : "Lock User", systemImage: user.accountLocked ? "lock.open" : "lock")
                    }

                    Menu("Script as", systemImage: "scroll") {
                        Button { openScriptTab(sql: "CREATE USER \(user.accountName);") } label: {
                            Label("CREATE USER", systemImage: "plus.square")
                        }
                        Button { openScriptTab(sql: "DROP USER IF EXISTS \(user.accountName);") } label: {
                            Label("DROP USER", systemImage: "minus.square")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        pendingDropUser = user.accountName
                    } label: {
                        Label("Drop User", systemImage: "trash")
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

            MySQLSecurityUserDetailSection(viewModel: viewModel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.md)
        }
        .onChange(of: viewModel.selectedUserID) { _, _ in
            Task { await viewModel.loadSelectedUserDetails() }
        }
        .dropConfirmationAlert(objectType: "User", objectName: $pendingDropUser) { _ in
            Task { await viewModel.dropSelectedUser() }
        }
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
