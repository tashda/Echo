import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension ConnectionEditorView {
    var detailView: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    generalSection
                    organizationSection
                    serverSection
                    authenticationSection
                    securitySection
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbarView
        }
    }

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("", text: $connectionName, prompt: Text("My Connection"))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Color") {
                HStack(spacing: 8) {
                    ForEach(Self.colorPalette, id: \.self) { hex in
                        Button {
                            colorHex = hex.uppercased()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .accentColor)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            Color.primary.opacity(colorHex.uppercased() == hex.uppercased() ? 0.6 : 0.2),
                                            lineWidth: colorHex.uppercased() == hex.uppercased() ? 2.5 : 1
                                        )
                                )
                                .overlay(
                                    Group {
                                        if colorHex.uppercased() == hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("General")
        }
    }

    private var organizationSection: some View {
        Section {
            Picker("Folder", selection: $folderID) {
                Text("Root").tag(nil as UUID?)
                ForEach(sortedFolders, id: \.id) { folder in
                    Text(folderDisplayName(folder)).tag(folder.id as UUID?)
                }
            }
            .onChange(of: folderID) { _, newFolderID in
                if newFolderID == nil && credentialSource == .inherit {
                    credentialSource = .manual
                }
            }
        } header: {
            Text("Organization")
        }
    }

    private var serverSection: some View {
        Section {
            LabeledContent(selectedDatabaseType == .sqlite ? "Database File" : "Host") {
                HStack(spacing: 8) {
                    TextField(
                        "",
                        text: $host,
                        prompt: Text(selectedDatabaseType == .sqlite ? "/path/to/database.sqlite" : "localhost")
                    )
                    .multilineTextAlignment(.trailing)

#if os(macOS)
                    if selectedDatabaseType == .sqlite {
                        Button("Browse…") {
                            browseForSQLiteFile()
                        }
                        .buttonStyle(.borderless)
                    }
#endif
                }
            }

            if selectedDatabaseType != .sqlite {
                LabeledContent("Port") {
                    TextField("", value: $port, format: .number.grouping(.never), prompt: Text("\(selectedDatabaseType.defaultPort)"))
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Database") {
                    TextField("", text: $database, prompt: Text("postgres (optional)"))
                        .multilineTextAlignment(.trailing)
                }
            } else {
                LabeledContent("Database") {
                    Text("Not required")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } header: {
            Text(selectedDatabaseType == .sqlite ? "Database" : "Server")
        }
    }

    private var authenticationSection: some View {
        Group {
            if selectedDatabaseType != .sqlite {
                Section {
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
                } header: {
                    Text("Authentication")
                }
            }
        }
    }

    private var manualCredentialFields: some View {
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

    private var identityPickerFields: some View {
        Group {
            if sortedIdentities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No identities available.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    HStack {
                        Spacer()
                        Button("Create Linked Identity…") {
                            identityEditorState = .create(parent: nil, token: UUID())
                        }
                        .buttonStyle(.link)
                    }
                }
            } else {
                Picker("Identity", selection: $identityID) {
                    ForEach(sortedIdentities, id: \.id) { identity in
                        Text(identity.name).tag(identity.id as UUID?)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Spacer()
                    Button("Create Linked Identity…") {
                        identityEditorState = .create(parent: nil, token: UUID())
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private var inheritedIdentityInfo: some View {
        Group {
            if let identity = inheritedIdentity {
                Text("This connection will use the identity '\(identity.name)' inherited from the selected folder.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The selected folder does not have credentials configured.")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    private var securitySection: some View {
        Group {
            if selectedDatabaseType != .sqlite {
                Section {
                    Toggle("Use SSL/TLS", isOn: $useTLS)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Enable encrypted connections when supported by the server.")
                }
            }
        }
    }

    var toolbarView: some View {
        HStack(spacing: 12) {
            Button(action: handleTestButton) {
                HStack(spacing: 6) {
                    if isTestingConnection {
                        ProgressView().controlSize(.small)
                        Text("Cancel Test")
                    } else {
                        Image(systemName: "link.badge.plus")
                        Text("Test Connection")
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(!isTestingConnection && !isFormValid)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                handleSave(action: .save)
            }
            .disabled(!isFormValid)

            Button("Save & Connect") {
                handleSave(action: .saveAndConnect)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}
