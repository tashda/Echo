import SwiftUI

extension FolderEditorSheet {

    // MARK: - Credentials

    @ViewBuilder
    var credentialsFormSection: some View {
        Section("Credentials") {
            PropertyRow(title: "Mode") {
                Picker("", selection: $credentialMode) {
                    Text("None").tag(FolderCredentialMode.none)
                    Text("Manual").tag(FolderCredentialMode.manual)
                    Text("Identity").tag(FolderCredentialMode.identity)
                    if canUseInheritance { Text("Inherit").tag(FolderCredentialMode.inherit) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            switch credentialMode {
            case .manual:
                PropertyRow(title: "Username") {
                    TextField("", text: $manualUsername, prompt: Text("shared_user"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "Password") {
                    SecureField("", text: Binding(
                        get: { manualPassword },
                        set: { manualPassword = $0; manualPasswordDirty = true }
                    ), prompt: Text("••••••••"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                }

                if editingFolderUsesManual && !manualPasswordDirty {
                    Text("Existing password will be kept unless changed.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .listRowSeparator(.hidden)
                }
            case .identity:
                identitySelectionContent
            case .inherit:
                if let identity = inheritedIdentity {
                    Text("Inherits identity \"\(identity.name)\" from parent folder.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.formDescription)
                        .listRowSeparator(.hidden)
                } else {
                    Text("Parent folder does not provide credentials.")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                        .listRowSeparator(.hidden)
                }
            case .none:
                EmptyView()
            }
        }
    }

    var identitySelectionContent: some View {
        Group {
            if availableIdentities.isEmpty {
                PropertyRow(title: "Identity") {
                    VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                        Text("No identities available.")
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .font(TypographyTokens.formDescription)
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
                        Picker("", selection: $selectedIdentityID) {
                            Text("Select").tag(UUID?.none)
                            ForEach(availableIdentities, id: \.id) {
                                Text($0.name).tag(UUID?.some($0.id))
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
                        .accessibilityLabel("Add identity")
                    }
                }
            }
        }
    }
}
