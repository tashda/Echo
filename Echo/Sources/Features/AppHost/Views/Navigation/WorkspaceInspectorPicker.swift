import SwiftUI

/// Round 39 RT2: details and saved SQL share the trailing column.
struct WorkspaceInspectorPicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Picker("Inspector content", selection: Binding(
            get: { appState.inspectorPage },
            set: { appState.showInspectorPage($0) }
        )) {
            ForEach([InspectorPage.details, .bookmarks, .history]) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()
    }
}
