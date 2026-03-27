import MySQLKit
import SwiftUI

struct MySQLSecurityUserDetailSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

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
        } else {
            ContentUnavailableView(
                "No User Selected",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Select a MySQL account to inspect grants, limits, and administrative roles.")
            )
        }
    }
}
