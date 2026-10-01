import SwiftUI

/// CN5: the selected connection's form, editable in place beside the list. The same form as
/// the Quick Connect and New Connection sheet, so there is one set of controls. Revert rebuilds
/// it from the saved connection.
struct ManageConnectionEditorPane: View {
    let connection: SavedConnection?
    let onSave: (SavedConnection, String?, ConnectionEditorView.SaveAction) -> Void

    @State private var revision = 0

    var body: some View {
        ConnectionEditorView(
            connection: connection,
            presentation: .inline,
            onRevert: { revision += 1 },
            onSave: onSave
        )
        .id("\(connection?.id.uuidString ?? "new")-\(revision)")
    }
}

/// What the pane shows when nothing is selected.
struct ManageConnectionEditorPlaceholder: View {
    let onNewConnection: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Connection Selected", systemImage: "externaldrive")
        } description: {
            Text("Select a connection to edit it here.")
        } actions: {
            Button("New Connection", action: onNewConnection)
        }
    }
}
