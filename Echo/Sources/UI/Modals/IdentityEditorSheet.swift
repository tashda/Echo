import SwiftUI

/// New Identity (and Edit Identity) as a sheet, opened from a connection's identity menu. The same
/// form as the identity pane in Manage Connections (round MC).
struct IdentityEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.dismiss) private var dismiss

    let state: IdentityEditorState
    var onSave: ((SavedIdentity) -> Void)? = nil

    @State private var draft = IdentityDraft()
    @State private var isSaving = false

    private var editingIdentity: SavedIdentity? {
        if case .edit(let identity) = state { return identity }
        return nil
    }

    private var isEditing: Bool { editingIdentity != nil }

    private var projectID: UUID? { editingIdentity?.projectID ?? projectStore.selectedProject?.id }

    private var hasDuplicateName: Bool {
        !isSaving && connectionStore.identityNameIsTaken(draft.name, projectID: projectID, excluding: editingIdentity?.id)
    }

    var body: some View {
        SheetLayout(
            title: isEditing ? "Edit Identity" : "New Identity",
            icon: "person.badge.key",
            subtitle: isEditing ? "Change the saved sign-in." : "A sign-in that several connections can share.",
            primaryAction: isEditing ? "Save" : "Create",
            canSubmit: draft.missing(isEditing: isEditing, hasDuplicateName: hasDuplicateName) == nil,
            isSubmitting: isSaving,
            onSubmit: { await saveIdentity() },
            onCancel: { dismiss() }
        ) {
            Form {
                IdentityFormSections(
                    draft: $draft,
                    isEditing: isEditing,
                    hasStoredPassword: editingIdentity?.keychainIdentifier != nil,
                    hasDuplicateName: hasDuplicateName
                )
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { draft = IdentityDraft(identity: editingIdentity) }
    }

    private func saveIdentity() async {
        isSaving = true
        let identity = await draft.save(
            over: editingIdentity,
            projectID: projectID,
            environmentState: environmentState,
            connectionStore: connectionStore
        )
        onSave?(identity)
        dismiss()
    }
}
