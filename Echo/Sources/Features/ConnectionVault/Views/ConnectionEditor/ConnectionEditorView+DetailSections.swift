import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Authentication Section

extension ConnectionEditorView {
    /// Round MC: sign in with the connection's own login (Password) or an identity. Kerberos,
    /// Windows and Entra tokens are under Method when the engine offers more than one.
    var authenticationSection: some View {
        Section("Sign In") {
            Picker("Sign in with", selection: $credentialSource) {
                Text("Password").tag(CredentialSource.manual)
                Text("Identity").tag(CredentialSource.identity)
            }
            .pickerStyle(.segmented)
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
                        identityID = usableIdentities.first?.id
                    }
                }
            }

            switch credentialSource {
            case .manual:
                manualCredentialFields
                validationRow(for: .password)
            case .identity:
                identityMenuRow
                validationRow(for: .username)
            }
        }
    }

    @ViewBuilder
    var manualCredentialFields: some View {
        if availableAuthenticationMethods.count > 1 {
            LabeledContent("Method") {
                Picker("", selection: $authenticationMethod) {
                    ForEach(availableAuthenticationMethods, id: \.self) { method in
                        Text(method.displayName(for: selectedDatabaseType)).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }

        if authenticationMethod.requiresDomain {
            InsetRow("Domain") {
                TextField("", text: $domain, prompt: Text("DOMAIN"))
                    .focused($focusedField, equals: .domain)
            }
            validationRow(for: .domain)
        }

        if authenticationMethod.usesAccessToken {
            InsetRow("Access Token") {
                SecureField("", text: $password, prompt: Text(hasSavedPassword && !passwordDirty ? "Saved in Keychain" : "JWT access token"))
                    .focused($focusedField, equals: .password)
                    .onChange(of: password) { _, newValue in
                        if !newValue.isEmpty { passwordDirty = true }
                    }
            }
        } else {
            InsetRow("User name") {
                TextField("", text: $username, prompt: Text("user name"))
                    .focused($focusedField, equals: .username)
            }
            validationRow(for: .username)

            if authenticationMethod == .kerberos {
                kerberosTicketRow
            }

            if authenticationMethod.usesPassword {
                InsetRow("Password") {
                    SecureField("", text: $password, prompt: Text(passwordPrompt))
                        .focused($focusedField, equals: .password)
                        .onChange(of: password) { _, newValue in
                            if !newValue.isEmpty { passwordDirty = true }
                        }
                }
            }
        }
    }

    private var passwordPrompt: String {
        if hasSavedPassword && !passwordDirty { return "Saved in Keychain" }
        return authenticationMethod == .windowsIntegrated ? "Windows password" : "password"
    }

    /// Identities whose kind this engine can sign in with.
    var usableIdentities: [SavedIdentity] {
        let methods = selectedDatabaseType.supportedAuthenticationMethods
        return sortedIdentities.filter { methods.contains($0.authenticationMethod) }
    }

    /// The identity menu: New Identity… first, then the identities (round MC, no explanation line).
    private var identityMenuRow: some View {
        LabeledContent("Identity") {
            Menu {
                Button {
                    identityEditorState = .create(token: UUID())
                } label: {
                    Label("New Identity…", systemImage: "plus")
                }
                if !usableIdentities.isEmpty {
                    Divider()
                    ForEach(usableIdentities) { identity in
                        Toggle(identity.name, isOn: Binding(
                            get: { identityID == identity.id },
                            set: { if $0 { identityID = identity.id } }
                        ))
                    }
                }
            } label: {
                Label(selectedIdentityName, systemImage: "person.crop.circle")
            }
            .menuStyle(.button)
            .fixedSize()
        }
    }

    private var selectedIdentityName: String {
        connectionStore.identities.first(where: { $0.id == identityID })?.name ?? "Choose"
    }

    /// The timeout rows, shown inside the Security & limits disclosure.
    var advancedRows: some View {
        Group {
            PropertyRow(title: "Connection Timeout") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField(
                        "",
                        value: $connectionTimeout,
                        format: .number.grouping(.never),
                        prompt: Text("30")
                    )
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("seconds")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            PropertyRow(title: "Keep Query History", info: "Runs on this connection are stored in Query History. Existing history can be cleared in Settings › Cache.") {
                Toggle("", isOn: $keepsQueryHistory)
                    .labelsHidden().toggleStyle(.switch)
            }

            PropertyRow(
                title: "Query Time Limit",
                info: "Stops a statement that runs longer than this. Empty uses Settings › Databases › Query time limit; 0 means no limit."
            ) {
                HStack(spacing: SpacingTokens.xs) {
                    TextField(
                        "",
                        value: $queryTimeLimit,
                        format: .number.grouping(.never),
                        prompt: Text("Default")
                    )
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("seconds")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            PropertyRow(
                title: "Confirm Unguarded Writes",
                info: "Asks before an UPDATE or DELETE without a WHERE runs on this connection. Settings › Databases sets the default for every connection."
            ) {
                Picker("", selection: $confirmUnguardedWrites) {
                    Text("Default").tag(Bool?.none)
                    Text("Always").tag(Bool?.some(true))
                    Text("Never").tag(Bool?.some(false))
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }
}
