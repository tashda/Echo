import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Authentication Section

extension ConnectionEditorView {
    var authenticationSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $credentialSource) {
                ForEach(availableCredentialSources, id: \.self) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: credentialSource) { _, newSource in
                switch newSource {
                case .manual:
                    // Reset dirty state so saved password shows as dots again
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

    var manualCredentialFields: some View {
        Group {
            if availableAuthenticationMethods.count > 1 {
                Picker("Authentication", selection: $authenticationMethod) {
                    ForEach(availableAuthenticationMethods, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.menu)
            }

            if authenticationMethod.requiresDomain {
                LabeledContent("Domain") {
                    TextField("", text: $domain, prompt: Text("DOMAIN"))
                        .multilineTextAlignment(.trailing)
                }
            }

            if authenticationMethod.usesAccessToken {
                LabeledContent("Access Token") {
                    SecureField(
                        "",
                        text: $password,
                        prompt: Text(hasSavedPassword && !passwordDirty
                            ? "••••••••"
                            : "JWT access token")
                    )
                    .multilineTextAlignment(.trailing)
                    .onChange(of: password) { _, newValue in
                        if !newValue.isEmpty {
                            passwordDirty = true
                        }
                    }
                }
            } else {
                LabeledContent("Username") {
                    TextField("", text: $username, prompt: Text("username"))
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Password") {
                    SecureField(
                        "",
                        text: $password,
                        prompt: Text(hasSavedPassword && !passwordDirty
                            ? "••••••••"
                            : (authenticationMethod == .windowsIntegrated ? "Windows password" : "password"))
                    )
                    .multilineTextAlignment(.trailing)
                    .onChange(of: password) { _, newValue in
                        if !newValue.isEmpty {
                            passwordDirty = true
                        }
                    }
                }
            }
        }
    }

    var identityPickerFields: some View {
        Group {
            if sortedIdentities.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("No identities available.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.detail)
                    Button("Create Identity") {
                        identityEditorState = .create(parent: nil, token: UUID())
                    }
                }
            } else {
                Picker("Identity", selection: $identityID) {
                    ForEach(sortedIdentities, id: \.id) { identity in
                        Text(identity.name).tag(identity.id as UUID?)
                    }
                }
                .pickerStyle(.menu)

                Button("Create Identity") {
                    identityEditorState = .create(parent: nil, token: UUID())
                }
            }
        }
    }

    var inheritedIdentityInfo: some View {
        Group {
            if let identity = inheritedIdentity {
                Text("This connection will use the identity \"\(identity.name)\" inherited from the selected folder.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The selected folder does not have credentials configured.")
                    .foregroundStyle(ColorTokens.Status.error)
                    .font(TypographyTokens.detail)
            }
        }
    }
}
