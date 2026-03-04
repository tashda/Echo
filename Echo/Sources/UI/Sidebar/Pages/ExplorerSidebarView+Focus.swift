import SwiftUI
import EchoSense

extension ExplorerSidebarView {
    internal func handleExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) {
        Task {
            await processExplorerFocus(focus, proxy: proxy)
        }
    }

    private func processExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) async {
        guard let session = await MainActor.run(body: {
            appModel.sessionManager.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run { navigationStore.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            viewModel.searchText = ""
            if selectedConnectionID != focus.connectionID {
                selectedConnectionID = focus.connectionID
            }
            appModel.sessionManager.setActiveSession(session.id)
        }

        if session.selectedDatabaseName?.localizedCaseInsensitiveCompare(focus.databaseName) != .orderedSame {
            await appModel.reconnectSession(session, to: focus.databaseName)
        }

        await appModel.refreshDatabaseStructure(for: session.id, scope: .selectedDatabase, databaseOverride: focus.databaseName)

        guard let refreshedSession = await MainActor.run(body: {
            appModel.sessionManager.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run { navigationStore.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            applyExplorerFocus(focus, session: refreshedSession, proxy: proxy)
            navigationStore.pendingExplorerFocus = nil
        }
    }

    private func applyExplorerFocus(_ focus: ExplorerFocus, session: ConnectionSession, proxy: ScrollViewProxy) {
        if viewModel.selectedSchemaName?.caseInsensitiveCompare(focus.schemaName) != .orderedSame {
            viewModel.selectedSchemaName = focus.schemaName
        }
        if !viewModel.expandedObjectGroups.contains(focus.objectType) {
            viewModel.expandedObjectGroups.insert(focus.objectType)
        }

        guard let structure = session.databaseStructure,
              let database = structure.databases.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.databaseName) == .orderedSame }),
              let schema = database.schemas.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.schemaName) == .orderedSame }) else {
            return
        }

        if let object = schema.objects.first(where: { $0.type == focus.objectType && $0.name.localizedCaseInsensitiveCompare(focus.objectName) == .orderedSame }) {
            viewModel.expandedObjectGroups.insert(object.type)
            let wasExpanded = viewModel.expandedObjectIDs.contains(object.id)
            if !wasExpanded {
                DispatchQueue.main.async {
                    self.viewModel.expandedObjectIDs.insert(object.id)
                }
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(object.id, anchor: .center)
            }
        }
    }
}
