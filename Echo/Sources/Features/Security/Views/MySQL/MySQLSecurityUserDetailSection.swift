import MySQLKit
import SwiftUI

struct MySQLSecurityUserDetailSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @State private var showLimitsSheet = false
    @State private var showAdministrativeRolesSheet = false
    @State private var showPasswordSheet = false

    var body: some View {
        if let user = viewModel.selectedUser {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
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
                    }
                }

                if !viewModel.selectedUserAdministrativeRoles.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Administrative Roles")
                            .font(TypographyTokens.detail.weight(.semibold))
                        Text(viewModel.selectedUserAdministrativeRoles.map(\.rawValue).joined(separator: ", "))
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                if let limits = viewModel.selectedUserLimits {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Account Limits")
                            .font(TypographyTokens.detail.weight(.semibold))
                        Text("Queries/hour: \(limits.maxQueriesPerHour)   Updates/hour: \(limits.maxUpdatesPerHour)   Connections/hour: \(limits.maxConnectionsPerHour)   User connections: \(limits.maxUserConnections)")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Grants")
                        .font(TypographyTokens.detail.weight(.semibold))
                    if viewModel.selectedUserGrants.isEmpty {
                        Text(viewModel.isLoadingUserDetails ? "Loading grants\u{2026}" : "No grants returned.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    } else {
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
            .sheet(isPresented: $showLimitsSheet) {
                if let limits = viewModel.selectedUserLimits {
                    MySQLUserLimitsSheet(accountName: user.accountName, initialLimits: limits) { updatedLimits in
                        Task { await viewModel.updateSelectedUserLimits(updatedLimits) }
                    } onDismiss: {
                        showLimitsSheet = false
                    }
                }
            }
            .sheet(isPresented: $showAdministrativeRolesSheet) {
                MySQLAdministrativeRolesSheet(
                    accountName: user.accountName,
                    initialRoles: Set(viewModel.selectedUserAdministrativeRoles)
                ) { roles in
                    Task { await viewModel.updateSelectedUserAdministrativeRoles(roles) }
                } onDismiss: {
                    showAdministrativeRolesSheet = false
                }
            }
            .sheet(isPresented: $showPasswordSheet) {
                MySQLUserPasswordSheet(accountName: user.accountName) { password in
                    Task { await viewModel.updateSelectedUserPassword(password) }
                } onDismiss: {
                    showPasswordSheet = false
                }
            }
        } else {
            ContentUnavailableView(
                "No User Selected",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Select a MySQL account to inspect grants, limits, and administrative roles.")
            )
        }
    }
}
