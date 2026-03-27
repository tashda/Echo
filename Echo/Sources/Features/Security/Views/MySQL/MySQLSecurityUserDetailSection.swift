import MySQLKit
import SwiftUI

struct MySQLSecurityUserDetailSection: View {
    enum DetailTab: String, CaseIterable {
        case login = "Login"
        case accountLimits = "Account Limits"
        case administrativeRoles = "Administrative Roles"
        case schemaPrivileges = "Schema Privileges"
        case grants = "Grants"
    }

    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @State var showLimitsSheet = false
    @State var showAdministrativeRolesSheet = false
    @State var showPasswordSheet = false
    @State var showRoleMembershipSheet = false
    @State var selectedDetailTab: DetailTab = .login

    var body: some View {
        if let user = viewModel.selectedUser {
            VStack(spacing: 0) {
                userHeader(user)
                Divider()
                TabSectionToolbar {
                    Picker("Detail Section", selection: $selectedDetailTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                }
                Divider()
                detailTabContent(for: user)
                    .padding(SpacingTokens.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .sheet(isPresented: $showRoleMembershipSheet) {
                MySQLUserRoleMembershipSheet(
                    accountName: user.accountName,
                    availableRoles: viewModel.roles,
                    initialRoleIDs: Set(viewModel.selectedUserRoleAssignments.map { "\($0.roleName)@\($0.roleHost)" })
                ) { roleIDs in
                    Task { await viewModel.updateSelectedUserRoleMembership(roleIDs) }
                } onDismiss: {
                    showRoleMembershipSheet = false
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
