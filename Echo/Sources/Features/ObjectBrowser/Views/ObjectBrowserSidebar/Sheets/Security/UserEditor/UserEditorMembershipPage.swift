import SwiftUI

struct UserEditorMembershipPage: View {
    @Bindable var viewModel: UserEditorViewModel

    private var fixedRoles: [Binding<UserEditorRoleMemberEntry>] {
        $viewModel.roleEntries.filter { $0.wrappedValue.isFixed }
    }

    private var customRoles: [Binding<UserEditorRoleMemberEntry>] {
        $viewModel.roleEntries.filter { !$0.wrappedValue.isFixed }
    }

    var body: some View {
        if viewModel.isLoadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database roles\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            if !fixedRoles.isEmpty {
                Section("Fixed Database Roles") {
                    ForEach(fixedRoles) { $role in
                        roleRow(role: $role)
                    }
                }
            }

            if !customRoles.isEmpty {
                Section("Custom Roles") {
                    ForEach(customRoles) { $role in
                        roleRow(role: $role)
                    }
                }
            }

            if fixedRoles.isEmpty && customRoles.isEmpty {
                Section {
                    Text("No database roles available.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func roleRow(role: Binding<UserEditorRoleMemberEntry>) -> some View {
        PropertyRow(title: role.wrappedValue.name) {
            Toggle("", isOn: role.isMember)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(role.wrappedValue.name == "public")
    }
}
