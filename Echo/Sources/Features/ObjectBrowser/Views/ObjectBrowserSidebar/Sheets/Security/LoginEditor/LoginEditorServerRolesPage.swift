import SwiftUI

struct LoginEditorServerRolesPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    private var fixedRoles: [Binding<LoginEditorRoleEntry>] {
        $viewModel.roleEntries.filter { $0.wrappedValue.isFixed }
    }

    private var customRoles: [Binding<LoginEditorRoleEntry>] {
        $viewModel.roleEntries.filter { !$0.wrappedValue.isFixed }
    }

    var body: some View {
        if viewModel.isLoadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading server roles\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            if !fixedRoles.isEmpty {
                Section("Fixed Server Roles") {
                    ForEach(fixedRoles) { $role in
                        roleRow(role: $role)
                    }
                }
            }

            if !customRoles.isEmpty {
                Section("Custom Server Roles") {
                    ForEach(customRoles) { $role in
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
    }

    @ViewBuilder
    private func roleRow(role: Binding<LoginEditorRoleEntry>) -> some View {
        PropertyRow(title: role.wrappedValue.name) {
            Toggle("", isOn: role.isMember)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(role.wrappedValue.name == "public")
    }
}
