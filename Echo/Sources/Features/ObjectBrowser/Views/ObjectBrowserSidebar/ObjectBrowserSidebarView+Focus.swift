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

        // Step 1: Expand tree state immediately (instant, no I/O)
        await MainActor.run {
            if selectedConnectionID != focus.connectionID {
                selectedConnectionID = focus.connectionID
            }
            environmentState.sessionGroup.setActiveSession(session.id)
            viewModel.ensureServerExpanded(for: focus.connectionID, sessions: sessions)
            viewModel.ensureDatabaseExpanded(connectionID: focus.connectionID, databaseName: focus.databaseName)
        }

        // Step 2: Check if the schema data is already cached — if so, skip the expensive network call
        let alreadyCached = await MainActor.run {
            hasCachedSchema(session: session, databaseName: focus.databaseName, schemaName: focus.schemaName, objectName: focus.objectName, objectType: focus.objectType)
        }

        if !alreadyCached {
            // Only reconnect/refresh if we don't have the data
            if session.sidebarFocusedDatabase?.localizedCaseInsensitiveCompare(focus.databaseName) != .orderedSame {
                await environmentState.reconnectSession(session, to: focus.databaseName)
            }
            await environmentState.refreshDatabaseStructure(for: session.id, scope: .selectedDatabase, databaseOverride: focus.databaseName)
        }

        // Step 3: Apply focus and scroll
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

    /// Checks if the target object already exists in the cached structure, avoiding expensive schema reload.
    private func hasCachedSchema(session: ConnectionSession, databaseName: String, schemaName: String, objectName: String, objectType: SchemaObjectInfo.ObjectType) -> Bool {
        guard let structure = session.databaseStructure else { return false }
        guard let database = structure.databases.first(where: {
            $0.name.localizedCaseInsensitiveCompare(databaseName) == .orderedSame
        }) else { return false }
        guard let schema = database.schemas.first(where: {
            $0.name.localizedCaseInsensitiveCompare(schemaName) == .orderedSame
        }) else { return false }
        return schema.objects.contains(where: {
            $0.type == objectType && $0.name.localizedCaseInsensitiveCompare(objectName) == .orderedSame
        })
    }

    private func applyExplorerFocus(_ focus: ExplorerFocus, session: ConnectionSession, proxy: ScrollViewProxy) {
        let connID = focus.connectionID
        let dbKey = "\(connID.uuidString)#\(focus.databaseName)"
        var groups = viewModel.expandedObjectGroupsBySession[dbKey] ?? Set(SchemaObjectInfo.ObjectType.allCases)
        if !groups.contains(focus.objectType) {
            groups.insert(focus.objectType)
            viewModel.expandedObjectGroupsBySession[dbKey] = groups
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
                ids.insert(object.id)
                viewModel.expandedObjectIDsBySession[dbKey] = ids
            }

            // Brief delay for SwiftUI to lay out the expanded tree, then scroll
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                let sidebarObjectID = ExplorerSidebarIdentity.object(
                    connectionID: connID,
                    databaseName: database.name,
                    objectID: object.id
                )
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(sidebarObjectID, anchor: .center)
                }
            }
        }
    }
}
