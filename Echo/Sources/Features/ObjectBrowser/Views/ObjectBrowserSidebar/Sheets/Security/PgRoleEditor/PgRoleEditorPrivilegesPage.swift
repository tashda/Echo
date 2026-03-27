import SwiftUI

struct PgRoleEditorPrivilegesPage: View {
    @Bindable var viewModel: PgRoleEditorViewModel

    var body: some View {
        Section("Login") {
            PropertyRow(
                title: "Can Login",
                info: "Allows this role to connect to the server as a session user."
            ) {
                Toggle("", isOn: $viewModel.canLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Superuser") {
            PropertyRow(
                title: "Superuser",
                info: "Grants all privileges and bypasses all permission checks. Use with caution."
            ) {
                Toggle("", isOn: $viewModel.isSuperuser)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Database Creation") {
            PropertyRow(
                title: "Can Create Databases",
                info: "Allows this role to create new databases."
            ) {
                Toggle("", isOn: $viewModel.canCreateDB)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Role Creation") {
            PropertyRow(
                title: "Can Create Roles",
                info: "Allows this role to create, alter, and drop other roles."
            ) {
                Toggle("", isOn: $viewModel.canCreateRole)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Inheritance") {
            PropertyRow(
                title: "Inherit Privileges",
                info: "Automatically inherits privileges of roles this role is a member of."
            ) {
                Toggle("", isOn: $viewModel.inherit)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Replication") {
            PropertyRow(
                title: "Replication",
                info: "Allows this role to initiate streaming replication."
            ) {
                Toggle("", isOn: $viewModel.isReplication)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Row Level Security") {
            PropertyRow(
                title: "Bypass Row Level Security",
                info: "Allows this role to bypass all row-level security policies."
            ) {
                Toggle("", isOn: $viewModel.bypassRLS)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
