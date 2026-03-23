import SwiftUI

struct LoginEditorStatusPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    var body: some View {
        Section("Connection") {
            PropertyRow(
                title: "Login enabled",
                info: "When disabled, the login cannot connect to SQL Server. Existing connections are not affected."
            ) {
                Toggle("", isOn: $viewModel.loginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        if viewModel.isEditing {
            Section("Account") {
                PropertyRow(title: "Authentication") {
                    Text(viewModel.authType == .sql ? "SQL Server Authentication" : "Windows Authentication")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }
}
