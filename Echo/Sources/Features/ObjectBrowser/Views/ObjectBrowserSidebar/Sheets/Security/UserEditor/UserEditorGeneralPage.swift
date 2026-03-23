import SwiftUI
import SQLServerKit

struct UserEditorGeneralPage: View {
    @Bindable var viewModel: UserEditorViewModel

    var body: some View {
        Section("Identity") {
            if !viewModel.isEditing {
                PropertyRow(title: "User Name") {
                    TextField("", text: $viewModel.userName, prompt: Text("e.g. app_user"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "User Type") {
                Picker("", selection: $viewModel.userType) {
                    ForEach(availableUserTypes) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(viewModel.isEditing)
            }
        }

        authenticationSection

        defaultsSection

        optionsSection

        Section {
            PropertyRow(title: "Database") {
                Text(viewModel.databaseName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - Available Types

    private var availableUserTypes: [DatabaseUserTypeChoice] {
        var types: [DatabaseUserTypeChoice] = [.mappedToLogin]
        if viewModel.isDatabaseContained {
            types.append(.withPassword)
        }
        types.append(contentsOf: [.withoutLogin, .windowsUser])
        if !viewModel.availableCertificates.isEmpty {
            types.append(.mappedToCertificate)
        }
        if !viewModel.availableAsymmetricKeys.isEmpty {
            types.append(.mappedToAsymmetricKey)
        }
        return types
    }

    // MARK: - Authentication Section

    @ViewBuilder
    private var authenticationSection: some View {
        switch viewModel.userType {
        case .mappedToLogin:
            Section("Login Mapping") {
                loginPicker
            }
        case .withPassword:
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
            }
        case .windowsUser:
            Section("Windows Principal") {
                PropertyRow(title: "Login Name") {
                    if viewModel.availableLogins.isEmpty {
                        TextField("", text: $viewModel.loginName, prompt: Text("DOMAIN\\username"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    } else {
                        loginPicker
                    }
                }
            }
        case .mappedToCertificate:
            Section("Certificate") {
                PropertyRow(title: "Certificate") {
                    Picker("", selection: $viewModel.selectedCertificate) {
                        Text("Select a certificate\u{2026}").tag("")
                        ForEach(viewModel.availableCertificates, id: \.name) { cert in
                            Text(cert.name).tag(cert.name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        case .mappedToAsymmetricKey:
            Section("Asymmetric Key") {
                PropertyRow(title: "Asymmetric Key") {
                    Picker("", selection: $viewModel.selectedAsymmetricKey) {
                        Text("Select a key\u{2026}").tag("")
                        ForEach(viewModel.availableAsymmetricKeys, id: \.name) { key in
                            Text(key.name).tag(key.name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        case .withoutLogin:
            EmptyView()
        }
    }

    // MARK: - Defaults Section

    @ViewBuilder
    private var defaultsSection: some View {
        Section("Defaults") {
            PropertyRow(title: "Default Schema") {
                TextField("", text: $viewModel.defaultSchema, prompt: Text("dbo"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            if viewModel.isDatabaseContained && viewModel.userType == .withPassword {
                PropertyRow(title: "Default Language") {
                    Picker("", selection: $viewModel.defaultLanguage) {
                        Text("Server default").tag("")
                        ForEach(viewModel.availableLanguages, id: \.name) { lang in
                            Text(lang.name).tag(lang.name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        Section("Options") {
            PropertyRow(
                title: "Allow Encrypted Value Modifications",
                info: "When ON, allows bulk copy of encrypted data between tables or databases without decrypting. Used with Always Encrypted."
            ) {
                Toggle("", isOn: $viewModel.allowEncryptedValueModifications)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Login Picker

    @ViewBuilder
    private var loginPicker: some View {
        PropertyRow(title: "Login Name") {
            if viewModel.availableLogins.isEmpty {
                TextField("", text: $viewModel.loginName, prompt: Text("login_name"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            } else {
                Picker("", selection: $viewModel.loginName) {
                    Text("Select a login\u{2026}").tag("")
                    ForEach(viewModel.availableLogins, id: \.self) { login in
                        Text(login).tag(login)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}
