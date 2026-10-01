import SwiftUI

/// Round 39 RT2: details and saved SQL share the trailing column.
struct WorkspaceInspectorPicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Picker("Inspector content", selection: Binding(
            get: { appState.workspaceLibrary?.rawValue ?? "Details" },
            set: { value in
                if let section = WorkspaceLibrarySection(rawValue: value) { appState.showWorkspaceLibrary(section) }
                else { appState.showInfoSidebar = true }
            }
        )) {
            Text("Details").tag("Details")
            ForEach(WorkspaceLibrarySection.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
        }.pickerStyle(.segmented).labelsHidden()
    }
}
