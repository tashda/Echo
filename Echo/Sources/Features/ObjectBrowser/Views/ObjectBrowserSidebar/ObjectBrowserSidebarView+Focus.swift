import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {
    internal func handleExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) {
        Task {
            await processExplorerFocus(focus, proxy: proxy)
        }
    }

    private func processExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) async {
        guard let session = await MainActor.run(body: {
            environmentState.sessionGroup.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run { navigationStore.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            viewModel.searchText = ""
            if selectedConnectionID != focus.connectionID {
                selectedConnectionID = focus.connectionID
            }
            environmentState.sessionGroup.setActiveSession(session.id)
            viewModel.ensureServerExpanded(for: focus.connectionID, sessions: sessions)
            viewModel.ensureDatabaseExpanded(connectionID: focus.connectionID, databaseName: focus.databaseName)
        }

        if session.selectedDatabaseName?.localizedCaseInsensitiveCompare(focus.databaseName) != .orderedSame {
            await environmentState.reconnectSession(session, to: focus.databaseName)
        }

        await environmentState.refreshDatabaseStructure(for: session.id, scope: .selectedDatabase, databaseOverride: focus.databaseName)

        guard let refreshedSession = await MainActor.run(body: {
            environmentState.sessionGroup.sessionForConnection(focus.connectionID)
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
        let connID = focus.connectionID
        let dbKey = "\(connID.uuidString)#\(focus.databaseName)"
        var groups = viewModel.expandedObjectGroupsBySession[dbKey] ?? Set(SchemaObjectInfo.ObjectType.allCases)
        if !groups.contains(focus.objectType) {
            groups.insert(focus.objectType)
            viewModel.expandedObjectGroupsBySession[dbKey] = groups
        }

        let currentSchema = viewModel.selectedSchemaNameBySession[dbKey]
        if currentSchema?.caseInsensitiveCompare(focus.schemaName) != .orderedSame {
            viewModel.selectedSchemaNameBySession[dbKey] = focus.schemaName
        }

        guard let structure = session.databaseStructure,
              let database = structure.databases.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.databaseName) == .orderedSame }),
              let schema = database.schemas.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.schemaName) == .orderedSame }) else {
            return
        }

        if let object = schema.objects.first(where: { $0.type == focus.objectType && $0.name.localizedCaseInsensitiveCompare(focus.objectName) == .orderedSame }) {
            groups.insert(object.type)
            viewModel.expandedObjectGroupsBySession[dbKey] = groups

            var ids = viewModel.expandedObjectIDsBySession[dbKey] ?? []
            if !ids.contains(object.id) {
                Task {
                    ids.insert(object.id)
                    self.viewModel.expandedObjectIDsBySession[dbKey] = ids
                }
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(object.id, anchor: .center)
            }
        }
    }
}
