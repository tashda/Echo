import SwiftUI

/// CN5 and round MC: the selected connection's form, editable in place beside the list. The same
/// form as the New Connection sheet, so there is one set of controls. Discard rebuilds it from the
/// saved connection; so does a save (the parent bumps `revision`).
struct ManageConnectionEditorPane: View {
    let connection: SavedConnection
    let revision: Int
    let saveRequest: Int
    let onChangesChanged: (Bool) -> Void
    let onSaveBlockerChanged: (String?) -> Void
    let onSave: (SavedConnection, String?, ConnectionEditorView.SaveAction) -> Void

    @State private var discardCount = 0

    var body: some View {
        ConnectionEditorView(
            connection: connection,
            presentation: .inline,
            confirmAction: .save,
            saveRequest: saveRequest,
            onChangesChanged: onChangesChanged,
            onSaveBlockerChanged: onSaveBlockerChanged,
            onRevert: {
                discardCount += 1
                onChangesChanged(false)
            },
            onSave: onSave
        )
        .id("\(connection.id.uuidString)-\(revision)-\(discardCount)")
    }
}
