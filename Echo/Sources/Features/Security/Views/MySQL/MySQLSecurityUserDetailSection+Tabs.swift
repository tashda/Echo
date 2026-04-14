import MySQLKit
import SwiftUI

extension MySQLSecurityUserDetailSection {
    @ViewBuilder
    func userHeader(_ user: MySQLUserAccount) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(user.accountName)
                    .font(TypographyTokens.headline)
                Text(user.authenticationPlugin ?? "No authentication plugin reported")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                Button("Change Password…") {
                    showPasswordSheet = true
                }
                .buttonStyle(.borderless)

                Button("Edit Limits…") {
                    showLimitsSheet = true
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.selectedUserLimits == nil)

                Button("Edit Admin Roles…") {
                    showAdministrativeRolesSheet = true
                }
                .buttonStyle(.borderless)

                Button("Edit Role Membership…") {
                    showRoleMembershipSheet = true
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(SpacingTokens.md)
    }

    @ViewBuilder
    func detailTabContent(for user: MySQLUserAccount) -> some View {
        switch selectedDetailTab {
        case .login:
            loginTab(user)
        case .accountLimits:
            accountLimitsTab
        case .administrativeRoles:
            administrativeRolesTab
        case .schemaPrivileges:
            schemaPrivilegesTab
        case .grants:
            grantsTab
        }
    }

    @ViewBuilder
    private func loginTab(_ user: MySQLUserAccount) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            detailRow("Username", value: user.username)
            detailRow("Host", value: user.host)
            detailRow("Authentication Plugin", value: user.authenticationPlugin ?? "Not reported")
            detailRow("Account Status", value: user.accountLocked ? "Locked" : "Unlocked")
            detailRow("Password Status", value: user.passwordExpired ? "Expired" : "Valid")
        }
    }

    @ViewBuilder
    private var accountLimitsTab: some View {
        if let limits = viewModel.selectedUserLimits {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                detailRow("Max Queries Per Hour", value: "\(limits.maxQueriesPerHour)")
                detailRow("Max Updates Per Hour", value: "\(limits.maxUpdatesPerHour)")
                detailRow("Max Connections Per Hour", value: "\(limits.maxConnectionsPerHour)")
                detailRow("Max User Connections", value: "\(limits.maxUserConnections)")
            }
        } else {
            emptyDetailState(
                title: "No Account Limits",
                message: viewModel.isLoadingUserDetails ? "Loading account limits…" : "No account limits are available for this user."
            )
        }
    }

    @ViewBuilder
    private var administrativeRolesTab: some View {
        if viewModel.selectedUserAdministrativeRoles.isEmpty {
            emptyDetailState(
                title: "No Administrative Roles",
                message: viewModel.isLoadingUserDetails ? "Loading administrative roles…" : "This user does not currently have any MySQL administrative roles."
            )
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(viewModel.selectedUserAdministrativeRoles.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { role in
                    Label(role.rawValue, systemImage: "checkmark.seal")
                        .font(TypographyTokens.detail)
                }
            }
        }
    }

    @ViewBuilder
    private var schemaPrivilegesTab: some View {
        if viewModel.selectedUserPrivileges.isEmpty {
            emptyDetailState(
                title: "No Schema Privileges",
                message: viewModel.isLoadingUserDetails ? "Loading schema privileges…" : "No schema-level privileges were found for this user."
            )
        } else {
            Table(viewModel.selectedUserPrivileges) {
                TableColumn("Schema") { privilege in
                    Text(privilege.tableSchema ?? "All Schemas")
                        .font(TypographyTokens.Table.secondaryName)
                }
                .width(min: 120, ideal: 160)

                TableColumn("Object") { privilege in
                    Text(privilege.tableName ?? "*")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Privilege") { privilege in
                    Text(privilege.privilegeType)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Grantable") { privilege in
                    Image(systemName: privilege.isGrantable ? "checkmark" : "minus")
                        .foregroundStyle(privilege.isGrantable ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                }
                .width(70)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
        }
    }

    @ViewBuilder
    private var grantsTab: some View {
        if viewModel.selectedUserGrants.isEmpty {
            emptyDetailState(
                title: "No Grants",
                message: viewModel.isLoadingUserDetails ? "Loading grants…" : "No grants were returned for this user."
            )
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(viewModel.selectedUserGrants, id: \.self) { grant in
                    Text(grant)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
            Text(title)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 180, alignment: .leading)
            Text(value)
                .font(TypographyTokens.detail)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func emptyDetailState(title: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "person.text.rectangle")
        } description: {
            Text(message)
        }
    }
}
