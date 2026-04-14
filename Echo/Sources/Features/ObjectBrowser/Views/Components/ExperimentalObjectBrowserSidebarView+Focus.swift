import EchoSense
import SwiftUI

extension ExperimentalObjectBrowserSidebarView {
    func handleExplorerFocus(_ focus: ExplorerFocus) {
        Task {
            await processExplorerFocus(focus)
        }
    }

    private func processExplorerFocus(_ focus: ExplorerFocus) async {
        guard let session = await MainActor.run(body: {
            environmentState.sessionGroup.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run {
                navigationStore.pendingExplorerFocus = nil
            }
            return
        }

        await MainActor.run {
            selectedConnectionID = focus.connectionID
            environmentState.sessionGroup.setActiveSession(session.id)
            viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.serverNodeID(connectionID: focus.connectionID))
            viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: focus.connectionID))
            viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.databaseNodeID(connectionID: focus.connectionID, databaseName: focus.databaseName))
            let groupNodeID = ExperimentalObjectBrowserSidebarViewModel.objectGroupNodeID(
                connectionID: focus.connectionID,
                databaseName: focus.databaseName,
                objectType: focus.objectType
            )
            viewModel.setExpanded(true, nodeID: groupNodeID)
        }

        let alreadyCached = await MainActor.run {
            hasCachedSchema(
                session: session,
                databaseName: focus.databaseName,
                schemaName: focus.schemaName,
                objectName: focus.objectName,
                objectType: focus.objectType
            )
        }

        if !alreadyCached {
            if session.sidebarFocusedDatabase?.localizedCaseInsensitiveCompare(focus.databaseName) != .orderedSame {
                await environmentState.reconnectSession(session, to: focus.databaseName)
            }
            await environmentState.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: focus.databaseName
            )
        }

        guard let refreshedSession = await MainActor.run(body: {
            environmentState.sessionGroup.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run {
                navigationStore.pendingExplorerFocus = nil
            }
            return
        }

        await MainActor.run {
            applyExplorerFocus(focus, session: refreshedSession)
            navigationStore.pendingExplorerFocus = nil
        }
    }

    private func hasCachedSchema(
        session: ConnectionSession,
        databaseName: String,
        schemaName: String,
        objectName: String,
        objectType: SchemaObjectInfo.ObjectType
    ) -> Bool {
        let structure = session.databaseStructure
        guard let structure,
              let database = structure.databases.first(where: {
                  $0.name.localizedCaseInsensitiveCompare(databaseName) == .orderedSame
              }),
              let schema = database.schemas.first(where: {
                  $0.name.localizedCaseInsensitiveCompare(schemaName) == .orderedSame
              }) else {
            return false
        }

        return schema.objects.contains(where: {
            $0.type == objectType && $0.name.localizedCaseInsensitiveCompare(objectName) == .orderedSame
        })
    }

    private func applyExplorerFocus(_ focus: ExplorerFocus, session: ConnectionSession) {
        guard let structure = session.databaseStructure,
              let database = structure.databases.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.databaseName) == .orderedSame }),
              let schema = database.schemas.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.schemaName) == .orderedSame }),
              let object = schema.objects.first(where: { $0.type == focus.objectType && $0.name.localizedCaseInsensitiveCompare(focus.objectName) == .orderedSame }) else {
            return
        }

        let objectGroupID = ExperimentalObjectBrowserSidebarViewModel.objectGroupNodeID(
            connectionID: focus.connectionID,
            databaseName: database.name,
            objectType: object.type
        )
        let objectNodeID = ExplorerSidebarIdentity.object(
            connectionID: focus.connectionID,
            databaseName: database.name,
            objectID: object.id
        )

        session.sidebarFocusedDatabase = database.name
        viewModel.selectedNodeID = objectNodeID
        viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.serverNodeID(connectionID: focus.connectionID))
        viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: focus.connectionID))
        viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.databaseNodeID(connectionID: focus.connectionID, databaseName: database.name))
        viewModel.setExpanded(true, nodeID: objectGroupID)
        viewModel.revealAndPulse(nodeID: objectNodeID)
    }
}
