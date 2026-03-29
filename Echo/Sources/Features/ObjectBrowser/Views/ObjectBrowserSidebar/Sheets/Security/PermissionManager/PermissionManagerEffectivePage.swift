import SwiftUI

struct PermissionManagerEffectivePage: View {
    @Bindable var viewModel: PermissionManagerViewModel

    @State private var sortOrder = [KeyPathComparator(\EffectivePermissionRow.permission)]

    private var sortedPermissions: [EffectivePermissionRow] {
        viewModel.effectivePermissions.sorted(using: sortOrder)
    }

    var body: some View {
        if viewModel.selectedPrincipalName.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No Principal Selected", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Select a principal from the sidebar to view effective permissions.")
                }
            }
        } else if viewModel.effectivePermissions.isEmpty && !viewModel.isLoadingEffective {
            Section {
                ContentUnavailableView {
                    Label("No Permissions", systemImage: "lock.open")
                } description: {
                    Text("No explicit permissions found for this principal.")
                }
            }
        } else {
            Section {
                Table(sortedPermissions, sortOrder: $sortOrder) {
                    TableColumn("Permission", value: \.permission) { row in
                        Text(row.permission)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("State") { row in
                        Text(row.state)
                            .font(TypographyTokens.Table.status)
                            .foregroundStyle(stateColor(for: row.state))
                    }
                    .width(min: 60, ideal: 100)

                    TableColumn("Securable Type") { row in
                        Text(row.securableClass)
                            .font(TypographyTokens.Table.category)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Securable") { row in
                        Text(row.securableName.isEmpty ? "\u{2014}" : row.securableName)
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(row.securableName.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    }
                    .width(min: 100, ideal: 160)

                    TableColumn("Grantor") { row in
                        Text(row.grantor)
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .width(min: 80, ideal: 120)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            } header: {
                Text("All Permissions for \(viewModel.selectedPrincipalName)")
            }
        }
    }

    private func stateColor(for state: String) -> Color {
        switch state {
        case "GRANT", "GRANT_WITH_GRANT_OPTION": ColorTokens.Status.success
        case "DENY": ColorTokens.Status.error
        case "REVOKE": ColorTokens.Text.tertiary
        default: ColorTokens.Text.secondary
        }
    }
}
