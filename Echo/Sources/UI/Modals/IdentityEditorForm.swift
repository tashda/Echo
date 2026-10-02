import SwiftUI

/// What the identity form edits (round MC), shared by the New Identity sheet and the identity pane
/// in Manage Connections. A typed password is never read back, so it counts as a change on its own.
struct IdentityDraft: Equatable {
    var name = ""
    var authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword
    var username = ""
    var domain = ""
    var password = ""
    var passwordDirty = false

    init() {}

    init(identity: SavedIdentity?) {
        guard let identity else { return }
        name = identity.name
        authenticationMethod = identity.authenticationMethod
        username = identity.username
        domain = identity.domain ?? ""
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What stops a save, in words, or nil when nothing does.
    func missing(isEditing: Bool, hasDuplicateName: Bool) -> String? {
        if trimmedName.isEmpty { return "Enter a name." }
        if hasDuplicateName { return "Another identity has this name." }
        let needsPassword = !isEditing && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if authenticationMethod.usesAccessToken {
            return needsPassword ? "Enter the access token." : nil
        }
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a user name." }
        return needsPassword ? "Enter the password." : nil
    }

    /// Saves the draft as a new identity or over `existing`, with its password, and returns it.
    @MainActor
    func save(
        over existing: SavedIdentity?,
        projectID: UUID?,
        folderID: UUID? = nil,
        environmentState: EnvironmentState,
        connectionStore: ConnectionStore
    ) async -> SavedIdentity {
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        var identity: SavedIdentity
        if var existing {
            existing.name = trimmedName
            existing.authenticationMethod = authenticationMethod
            existing.username = trimmedUsername
            existing.domain = trimmedDomain.isEmpty ? nil : trimmedDomain
            existing.updatedAt = Date()
            identity = existing
        } else {
            identity = SavedIdentity(
                projectID: projectID,
                name: trimmedName,
                authenticationMethod: authenticationMethod,
                username: trimmedUsername,
                domain: trimmedDomain.isEmpty ? nil : trimmedDomain,
                keychainIdentifier: "echo.identity.\(UUID().uuidString)"
            )
            identity.folderID = folderID
        }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing == nil || (passwordDirty && !trimmedPassword.isEmpty) {
            try? environmentState.identityRepository.setPassword(password, for: &identity)
        }
        try? await connectionStore.updateIdentity(identity)
        return identity
    }
}

/// The identity's form sections: name, then how it signs in. Rows are inset rows, like the
/// connection form (Design/05-components › Connections).
struct IdentityFormSections: View {
    @Binding var draft: IdentityDraft
    let isEditing: Bool
    let hasStoredPassword: Bool
    let hasDuplicateName: Bool

    var body: some View {
        Section {
            InsetRow("Name") {
                TextField("", text: $draft.name, prompt: Text("Production"))
            }
            if hasDuplicateName {
                Label("Another identity in this project has this name.", systemImage: "exclamationmark.circle.fill")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .listRowSeparator(.hidden)
            }
        }

        Section("Sign in") {
            LabeledContent("Method") {
                Picker("", selection: $draft.authenticationMethod) {
                    ForEach(DatabaseAuthenticationMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            if draft.authenticationMethod.usesAccessToken {
                InsetRow("Access Token") {
                    SecureField("", text: passwordBinding, prompt: Text(passwordPrompt(fallback: "JWT access token")))
                }
            } else {
                if draft.authenticationMethod.requiresDomain {
                    InsetRow("Domain") {
                        TextField("", text: $draft.domain, prompt: Text("DOMAIN"))
                    }
                }
                InsetRow("User name") {
                    TextField("", text: $draft.username, prompt: Text("db_admin"))
                }
                InsetRow("Password") {
                    SecureField("", text: passwordBinding, prompt: Text(passwordPrompt(fallback: "Required")))
                }
            }
        }
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { draft.password },
            set: { draft.password = $0; draft.passwordDirty = true }
        )
    }

    /// A saved password shows as dots and is kept unless something is typed.
    private func passwordPrompt(fallback: String) -> String {
        isEditing && hasStoredPassword && !draft.passwordDirty ? "••••••••" : fallback
    }
}

extension ConnectionStore {
    /// Whether another identity in the project already has this name.
    func identityNameIsTaken(_ name: String, projectID: UUID?, excluding id: UUID?) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return identities.contains {
            $0.projectID == projectID && $0.id != id
                && $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }
}
