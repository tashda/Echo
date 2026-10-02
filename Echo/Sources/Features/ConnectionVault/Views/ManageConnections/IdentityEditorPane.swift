import SwiftUI

/// Round MC (MC-6): the selected identity, edited in place beside the list, with the same toolbar as
/// the connection pane: Discard (after an edit) or Cancel (a new identity) on the left, the name in
/// the middle, Save (✓) on the right, dimmed until it can save. Below the form: the connections
/// that sign in with it, and Delete.
struct IdentityEditorPane: View {
    let identity: SavedIdentity?
    let revision: Int
    let saveRequest: Int
    let usedBy: [SavedConnection]
    let onChangesChanged: (Bool) -> Void
    let onSaveBlockerChanged: (String?) -> Void
    let onSaved: (SavedIdentity) -> Void
    let onCancel: (() -> Void)?
    let onDelete: (SavedIdentity) -> Void

    var body: some View {
        IdentityEditorPaneContent(
            identity: identity,
            saveRequest: saveRequest,
            usedBy: usedBy,
            onChangesChanged: onChangesChanged,
            onSaveBlockerChanged: onSaveBlockerChanged,
            onSaved: onSaved,
            onCancel: onCancel,
            onDelete: onDelete
        )
        // A save or a discard rebuilds the form from the saved identity.
        .id("\(identity?.id.uuidString ?? "new")-\(revision)")
    }
}

private struct IdentityEditorPaneContent: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState

    let identity: SavedIdentity?
    let saveRequest: Int
    let usedBy: [SavedConnection]
    let onChangesChanged: (Bool) -> Void
    let onSaveBlockerChanged: (String?) -> Void
    let onSaved: (SavedIdentity) -> Void
    let onCancel: (() -> Void)?
    let onDelete: (SavedIdentity) -> Void

    @State private var draft: IdentityDraft
    @State private var initialDraft: IdentityDraft
    @State private var isSaving = false

    init(
        identity: SavedIdentity?,
        saveRequest: Int,
        usedBy: [SavedConnection],
        onChangesChanged: @escaping (Bool) -> Void,
        onSaveBlockerChanged: @escaping (String?) -> Void,
        onSaved: @escaping (SavedIdentity) -> Void,
        onCancel: (() -> Void)?,
        onDelete: @escaping (SavedIdentity) -> Void
    ) {
        self.identity = identity
        self.saveRequest = saveRequest
        self.usedBy = usedBy
        self.onChangesChanged = onChangesChanged
        self.onSaveBlockerChanged = onSaveBlockerChanged
        self.onSaved = onSaved
        self.onCancel = onCancel
        self.onDelete = onDelete
        let start = IdentityDraft(identity: identity)
        _draft = State(initialValue: start)
        _initialDraft = State(initialValue: start)
    }

    private var isEditing: Bool { identity != nil }
    private var hasChanges: Bool { draft != initialDraft }
    private var projectID: UUID? { identity?.projectID ?? projectStore.selectedProject?.id }

    private var hasDuplicateName: Bool {
        !isSaving && connectionStore.identityNameIsTaken(draft.name, projectID: projectID, excluding: identity?.id)
    }

    /// What stops a save, ignoring "nothing changed": the leave alert's Save depends on it.
    private var saveBlocker: String? {
        draft.missing(isEditing: isEditing, hasDuplicateName: hasDuplicateName)
    }

    private var missingForSave: String? {
        if let missing = draft.missing(isEditing: isEditing, hasDuplicateName: hasDuplicateName) { return missing }
        if isEditing && !hasChanges { return "Nothing to save" }
        return nil
    }

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            toolbar
            Form {
                IdentityFormSections(
                    draft: $draft,
                    isEditing: isEditing,
                    hasStoredPassword: identity?.keychainIdentifier != nil,
                    hasDuplicateName: hasDuplicateName
                )
                if let identity {
                    usedBySection
                    Section {
                        Button("Delete Identity…", role: .destructive) { onDelete(identity) }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .onSubmit { if missingForSave == nil { save() } }
        }
        .onChange(of: hasChanges) { _, changed in
            // A new identity counts as changed from the start, so leaving it asks first.
            onChangesChanged(changed || !isEditing)
        }
        .onAppear { if !isEditing { onChangesChanged(true) } }
        .onChange(of: saveBlocker, initial: true) { _, blocker in onSaveBlockerChanged(blocker) }
        .onChange(of: saveRequest) { _, _ in
            if missingForSave == nil { save() }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            Group {
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.glass)
                        .keyboardShortcut(.cancelAction)
                } else if hasChanges {
                    Button("Discard") {
                        draft = initialDraft
                        onChangesChanged(false)
                    }
                    .buttonStyle(.glass)
                    .help("Discard your changes")
                }
            }
            .frame(width: ConnectionEditorHeaderMetrics.sideWidth, alignment: .leading)

            VStack(spacing: SpacingTokens.micro) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button(action: save) {
                Group {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .frame(width: ConnectionEditorHeaderMetrics.glyphSize, height: ConnectionEditorHeaderMetrics.glyphSize)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(missingForSave != nil || isSaving)
            .keyboardShortcut("s", modifiers: .command)
            .help(missingForSave ?? "Save (⌘S)")
            .accessibilityLabel("Save")
            .frame(width: ConnectionEditorHeaderMetrics.sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var title: String {
        guard isEditing else { return "New Identity" }
        return draft.trimmedName.isEmpty ? "Identity" : draft.trimmedName
    }

    private var subtitle: String {
        let method = draft.authenticationMethod.displayName
        return isEditing && hasChanges ? "\(method) · Edited" : method
    }

    // MARK: Used by

    private var usedBySection: some View {
        Section("Used by") {
            if usedBy.isEmpty {
                Text("No connection signs in with this identity.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                ForEach(usedBy) { connection in
                    HStack(spacing: SpacingTokens.xs) {
                        Image(connection.databaseType.iconName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
                            .lineLimit(1)
                        Spacer()
                        Text(connection.host)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    // MARK: Saving

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            let saved = await draft.save(
                over: identity,
                projectID: projectID,
                environmentState: environmentState,
                connectionStore: connectionStore
            )
            isSaving = false
            onSaved(saved)
        }
    }
}
