import SwiftUI

/// Shared "Script as" menu content used by both the Object Browser context menu
/// and the Search sidebar context menu. Renders grouped script action buttons.
struct ScriptAsMenuContent: View {
    let actions: [ScriptAction]
    let databaseType: DatabaseType
    let onAction: (ScriptAction) -> Void

    var body: some View {
        let readActions = actions.filter(\.isReadGroup)
        let createActions = actions.filter(\.isCreateModifyGroup)
        let writeActions = actions.filter(\.isWriteGroup)
        let executeActions = actions.filter(\.isExecuteGroup)
        let destroyActions = actions.filter(\.isDestroyGroup)

        ForEach(readActions, id: \.identifier) { action in
            actionButton(action)
        }
        if !readActions.isEmpty && !createActions.isEmpty {
            Divider()
        }
        ForEach(createActions, id: \.identifier) { action in
            actionButton(action)
        }
        if !createActions.isEmpty && !writeActions.isEmpty {
            Divider()
        }
        ForEach(writeActions, id: \.identifier) { action in
            actionButton(action)
        }
        if !writeActions.isEmpty && !executeActions.isEmpty {
            Divider()
        }
        if writeActions.isEmpty && !createActions.isEmpty && !executeActions.isEmpty {
            Divider()
        }
        ForEach(executeActions, id: \.identifier) { action in
            actionButton(action)
        }

        let lastNonDestroy = !executeActions.isEmpty || !writeActions.isEmpty
            || !createActions.isEmpty || !readActions.isEmpty
        if lastNonDestroy && !destroyActions.isEmpty {
            Divider()
        }
        ForEach(destroyActions, id: \.identifier) { action in
            actionButton(action)
        }
    }

    private func actionButton(_ action: ScriptAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(action.title(for: databaseType), systemImage: action.systemImage)
        }
    }
}
