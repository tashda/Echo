import SwiftUI

struct LoginEditorGeneralPage: View {
    @Bindable var viewModel: LoginEditorViewModel

    var body: some View {
        Section("Authentication") {
            if !viewModel.isEditing {
                PropertyRow(title: "Login Name") {
                    TextField("", text: $viewModel.loginName, prompt: Text("login_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Type") {
                Picker("", selection: $viewModel.authType) {
                    Text("SQL Server").tag(LoginAuthType.sql)
                    Text("Windows").tag(LoginAuthType.windows)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(viewModel.isEditing)
            }

            PropertyRow(
                title: "Login enabled",
                info: "When disabled, the login cannot connect to SQL Server. Existing connections are not affected."
            ) {
                Toggle("", isOn: $viewModel.loginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if viewModel.isEditing && viewModel.authType == .sql {
                PropertyRow(
                    title: "Login is locked out",
                    info: "Indicates if the login is currently locked out due to failed password attempts."
                ) {
                    Toggle("", isOn: $viewModel.isLocked)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(true) // Locked status is read-only
                }
            }
        }

        if viewModel.authType == .sql {
            Section("Credentials") {
                PropertyRow(title: "Password") {
                    SecureField(
                        "", text: $viewModel.password,
                        prompt: Text(viewModel.isEditing ? "Leave empty to keep current" : "Required")
                    )
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                }

                if !viewModel.isEditing {
                    PropertyRow(title: "Confirm Password") {
                        SecureField("", text: $viewModel.confirmPassword, prompt: Text("Re-enter password"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                PropertyRow(
                    title: "Enforce policy",
                    info: "Applies Windows password policies (complexity, lockout) to this SQL Server login."
                ) {
                    Toggle("", isOn: $viewModel.enforcePasswordPolicy)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Enforce expiration",
                    info: "Applies Windows password expiration policy. Requires Enforce policy to be enabled."
                ) {
                    Toggle("", isOn: $viewModel.enforcePasswordExpiration)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!viewModel.enforcePasswordPolicy)
                }
            }
        }

        Section("Status") {
            PropertyRow(title: "Permission to connect to database engine") {
                Picker("", selection: $viewModel.isConnectSQLGranted) {
                    Text("Grant").tag(LoginEditorViewModel.ConnectPermissionState.granted)
                    Text("Deny").tag(LoginEditorViewModel.ConnectPermissionState.denied)
                    Text("Unspecified").tag(LoginEditorViewModel.ConnectPermissionState.unspecified)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            if viewModel.isEditing && viewModel.authType == .sql {
                PropertyRow(title: "Login is locked out") {
                    Toggle("", isOn: $viewModel.isLocked)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(true)
                }
            }
        }

        Section("Defaults") {
            PropertyRow(title: "Default Database") {
                Picker("", selection: $viewModel.defaultDatabase) {
                    ForEach(viewModel.availableDatabases, id: \.self) { db in
                        Text(db).tag(db)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Default Language") {
                TextField("", text: $viewModel.defaultLanguage, prompt: Text("Server default"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
