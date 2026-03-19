import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Authentication Section

extension ConnectionEditorView {
    var authenticationSection: some View {
        Section("Authentication") {
            PropertyRow(title: "Method") {
                Picker("", selection: $credentialSource) {
                    ForEach(availableCredentialSources, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: credentialSource) { _, newSource in
                switch newSource {
                case .manual:
                    if hasSavedPassword {
                        passwordDirty = false
                        password = ""
                    }
                case .identity:
                    password = ""
                    passwordDirty = false
                    if identityID == nil || !connectionStore.identities.contains(where: { $0.id == identityID }) {
                        identityID = connectionStore.identities.first?.id
                    }
                case .inherit:
                    password = ""
                    passwordDirty = false
                }
            }

            switch credentialSource {
            case .manual:
                manualCredentialFields
            case .identity:
                identityPickerFields
            case .inherit:
                inheritedIdentityInfo
            }
        }
    }

    @ViewBuilder
    var manualCredentialFields: some View {
        if availableAuthenticationMethods.count > 1 {
            PropertyRow(title: "Mechanism") {
                Picker("", selection: $authenticationMethod) {
                    ForEach(availableAuthenticationMethods, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        if authenticationMethod.requiresDomain {
            PropertyRow(title: "Domain") {
                TextField("", text: $domain, prompt: Text("DOMAIN"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        if authenticationMethod.usesAccessToken {
            PropertyRow(title: "Access Token") {
                SecureField(
                    "",
                    text: $password,
                    prompt: Text(hasSavedPassword && !passwordDirty
                        ? "••••••••"
                        : "JWT access token")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .onChange(of: password) { _, newValue in
                    if !newValue.isEmpty {
                        passwordDirty = true
                    }
                }
            }
        } else {
            PropertyRow(title: "Username") {
                TextField("", text: $username, prompt: Text("username"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Password") {
                SecureField(
                    "",
                    text: $password,
                    prompt: Text(hasSavedPassword && !passwordDirty
                        ? "••••••••"
                        : (authenticationMethod == .windowsIntegrated ? "Windows password" : "password"))
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .onChange(of: password) { _, newValue in
                    if !newValue.isEmpty {
                        passwordDirty = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    var identityPickerFields: some View {
        if sortedIdentities.isEmpty {
            PropertyRow(title: "Identity") {
                VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                    Text("No identities available.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    
                    Button("Create Identity") {
                        identityEditorState = .create(parent: nil, token: UUID())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } else {
            PropertyRow(title: "Identity") {
                HStack(spacing: SpacingTokens.xs) {
                    Picker("", selection: $identityID) {
                        ForEach(sortedIdentities, id: \.id) { identity in
                            Text(identity.name).tag(identity.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    
                    Button {
                        identityEditorState = .create(parent: nil, token: UUID())
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    var inheritedIdentityInfo: some View {
        if let identity = inheritedIdentity {
            PropertyRow(title: "Inherited") {
                Text(identity.name)
                    .font(TypographyTokens.formValue)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Text("Inherited from folder.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .listRowSeparator(.hidden)
        } else {
            PropertyRow(title: "Inherited") {
                Text("None")
                    .font(TypographyTokens.formValue)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }
}
