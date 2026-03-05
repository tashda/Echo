import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

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
                    break
                case .identity:
                    password = ""
                    if identityID == nil || !connectionStore.identities.contains(where: { $0.id == identityID }) {
                        identityID = connectionStore.identities.first?.id
                    }
                case .inherit:
                    password = ""
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

            LabeledContent("Username") {
                TextField("", text: $username, prompt: Text("username"))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Password") {
                SecureField("", text: $password, prompt: Text(authenticationMethod == .windowsIntegrated ? "Windows password" : "password"))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    var identityPickerFields: some View {
        Group {
            if sortedIdentities.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("No identities available.")
                        .foregroundStyle(.secondary)
                        .font(TypographyTokens.detail)
                    Button("Create Identity...") {
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

                Button("Create Identity...") {
                    identityEditorState = .create(parent: nil, token: UUID())
                }
            }
        }
    }

    var inheritedIdentityInfo: some View {
        Group {
            if let identity = inheritedIdentity {
                Text("This connection will use the identity \"\(identity.name)\" inherited from the selected folder.")
                    .foregroundStyle(.secondary)
                    .font(TypographyTokens.detail)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The selected folder does not have credentials configured.")
                    .foregroundStyle(.red)
                    .font(TypographyTokens.detail)
            }
        }
    }

    var securitySection: some View {
        Section("Security") {
            Toggle("Use SSL/TLS", isOn: $useTLS)
        }
    }
}
