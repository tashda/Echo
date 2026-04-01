import SwiftUI

struct LoginEditorServerRolesPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    private var fixedRoles: [Binding<LoginEditorRoleEntry>] {
        $viewModel.roleEntries.filter { isFixedOrSystem($0.wrappedValue) }
    }

    private var customRoles: [Binding<LoginEditorRoleEntry>] {
        $viewModel.roleEntries.filter { !isFixedOrSystem($0.wrappedValue) }
    }

    private func isFixedOrSystem(_ entry: LoginEditorRoleEntry) -> Bool {
        entry.isFixed || entry.name == "public" || entry.name.hasPrefix("##MS_")
    }

    var body: some View {
        if !customRoles.isEmpty {
            Section("Custom Server Roles") {
                ForEach(customRoles) { $role in
                    roleRow(role: $role)
                }
            }
        }

        if !fixedRoles.isEmpty {
            Section("Fixed Server Roles") {
                ForEach(fixedRoles) { $role in
                    roleRow(role: $role)
                }
            }
        }

        if fixedRoles.isEmpty && customRoles.isEmpty {
            Section {
                Text("No server roles available.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private func roleRow(role: Binding<LoginEditorRoleEntry>) -> some View {
        PropertyRow(title: role.wrappedValue.name) {
            Toggle("", isOn: role.isMember)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
