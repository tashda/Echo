import SwiftUI

extension AccountDetailSheet {

    // MARK: - Profile

    var profileSection: some View {
        Section("Profile") {
            // Name
            if isEditingName {
                HStack {
                    TextField("", text: $editedName, prompt: Text("Your name"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveDisplayName() }

                    Button("Save") { saveDisplayName() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.small)
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") { isEditingName = false }
                        .controlSize(.small)
                }
            } else {
                PropertyRow(title: "Name") {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(authState.currentUser?.displayName ?? "Not set")
                            .foregroundStyle(authState.currentUser?.displayName != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                        Button {
                            editedName = authState.currentUser?.displayName ?? ""
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Email
            if let email = authState.currentUser?.email {
                PropertyRow(title: "Email") {
                    Text(email)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            // Auth Method
            if let method = authState.currentUser?.authMethod {
                PropertyRow(title: "Sign-in method") {
                    HStack(spacing: 4) {
                        authMethodIcon(method)
                        Text(method.displayName)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    var actionsSection: some View {
        Section {
            HStack {
                Button("Sign Out") {
                    Task {
                        await authState.signOut()
                        dismiss()
                    }
                }

                Spacer()

                Button("Delete Account", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .font(TypographyTokens.formDescription)
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await authState.deleteAccount()
                            dismiss()
                        } catch {
                            return
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all synced data. This action cannot be undone.")
            }

            if let error = authState.error {
                Text(error.localizedDescription)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    // MARK: - Auth Method Icon

    @ViewBuilder
    func authMethodIcon(_ method: AuthMethod) -> some View {
        switch method {
        case .google:
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
        case .apple:
            Image(systemName: "apple.logo")
                .font(TypographyTokens.detail)
        case .email:
            Image(systemName: "envelope.fill")
                .font(TypographyTokens.detail)
        }
    }

    // MARK: - Helpers

    func saveDisplayName() {
        let name = editedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isEditingName = false
        Task { await authState.updateDisplayName(name) }
    }
}
