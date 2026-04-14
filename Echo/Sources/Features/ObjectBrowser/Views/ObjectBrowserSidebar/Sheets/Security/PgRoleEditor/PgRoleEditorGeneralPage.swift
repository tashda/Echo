import SwiftUI

struct PgRoleEditorGeneralPage: View {
    @Bindable var viewModel: PgRoleEditorViewModel

    var body: some View {
        identitySection
        expirationSection
        descriptionSection
    }

    // MARK: - Identity

    @ViewBuilder
    private var identitySection: some View {
        Section("Identity") {
            if viewModel.isEditing {
                PropertyRow(title: "Role Name") {
                    Text(viewModel.roleName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                PropertyRow(title: "Role Name") {
                    TextField("", text: $viewModel.roleName, prompt: Text("e.g. app_readonly"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Password") {
                SecureField(
                    "",
                    text: $viewModel.password,
                    prompt: Text(viewModel.isEditing ? "Leave empty to keep current" : "Optional")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
            }

            if !viewModel.isEditing {
                PropertyRow(title: "Confirm Password") {
                    SecureField("", text: $viewModel.passwordConfirm, prompt: Text("Re-enter password"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(
                title: "Connection Limit",
                info: "Maximum concurrent connections. Use -1 for unlimited."
            ) {
                TextField("", text: $viewModel.connectionLimit, prompt: Text("e.g. -1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Expiration

    @ViewBuilder
    private var expirationSection: some View {
        Section("Expiration") {
            PropertyRow(title: "Password expires") {
                Toggle("", isOn: $viewModel.hasExpiration)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if viewModel.hasExpiration {
                PropertyRow(title: "Expires on") {
                    DatePicker(
                        "",
                        selection: $viewModel.validUntil,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                }
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        Section("Description") {
            PropertyRow(title: "Comment") {
                TextField(
                    "",
                    text: $viewModel.description,
                    prompt: Text("Optional description for this role"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .multilineTextAlignment(.trailing)
            }
        }
    }
}
