import SwiftUI

/// Round MC: the right column edits whatever is selected, in place (CN5): one connection, one
/// identity, a new identity, or a summary when several connections are selected.
extension ManageConnectionsView {
    @ViewBuilder
    var detailColumn: some View {
        if activeScope.isConnections {
            connectionDetail
        } else {
            identityDetail
        }
    }

    @ViewBuilder
    private var connectionDetail: some View {
        if isCreatingConnection {
            // R2-B (NB1): a new connection is made here, engine first, like editing.
            ConnectionEditorView(
                connection: nil,
                presentation: .inline,
                confirmAction: .save,
                saveRequest: saveRequest,
                onChangesChanged: { detailHasChanges = $0 },
                onSaveBlockerChanged: { detailSaveBlocker = $0 },
                onRevert: cancelNewConnection,
                onSave: handleNewConnectionSave
            )
            .id("new-connection-\(editorRevision)")
        } else if connectionSelection.count == 1, let id = connectionSelection.first,
           let connection = connectionStore.connections.first(where: { $0.id == id }) {
            ManageConnectionEditorPane(
                connection: connection,
                revision: editorRevision,
                saveRequest: saveRequest,
                onChangesChanged: { detailHasChanges = $0 },
                onSaveBlockerChanged: { detailSaveBlocker = $0 },
                onSave: handleConnectionEditorSave
            )
        } else if connectionSelection.count > 1 {
            let selected = connectionStore.connections.filter { connectionSelection.contains($0.id) }
            ContentUnavailableView {
                Label("\(selected.count) Connections", systemImage: "square.stack")
            } description: {
                Text(selected.map { displayName(for: $0) }.joined(separator: ", "))
                    .lineLimit(3)
            } actions: {
                Button("Delete \(selected.count) Connections…", role: .destructive) { deleteConnections(selected) }
            }
        } else {
            ContentUnavailableView {
                Label("Select a Connection", systemImage: "externaldrive")
            } description: {
                Text("Select one to edit it here, or double-click it to connect.")
            } actions: {
                Button("New Connection…") { navigate(to: .newConnection) }
            }
        }
    }

    @ViewBuilder
    private var identityDetail: some View {
        if isCreatingIdentity {
            IdentityEditorPane(
                identity: nil,
                folderID: currentFolderID,
                revision: editorRevision,
                saveRequest: saveRequest,
                usedBy: [],
                onChangesChanged: { detailHasChanges = $0 },
                onSaveBlockerChanged: { detailSaveBlocker = $0 },
                onSaved: handleIdentitySaved,
                onCancel: { isCreatingIdentity = false; detailHasChanges = false },
                onDelete: { _ in }
            )
        } else if identitySelection.count == 1, let id = identitySelection.first,
                  let identity = connectionStore.identities.first(where: { $0.id == id }) {
            IdentityEditorPane(
                identity: identity,
                folderID: nil,
                revision: editorRevision,
                saveRequest: saveRequest,
                usedBy: connections(using: identity),
                onChangesChanged: { detailHasChanges = $0 },
                onSaveBlockerChanged: { detailSaveBlocker = $0 },
                onSaved: handleIdentitySaved,
                onCancel: nil,
                onDelete: { pendingDeletion = .identity($0) }
            )
        } else {
            ContentUnavailableView {
                Label("Select an Identity", systemImage: "person.crop.circle")
            } description: {
                Text("An identity is a login that several connections share.")
            } actions: {
                Button("New Identity") { navigate(to: .newIdentity) }
            }
        }
    }
}
