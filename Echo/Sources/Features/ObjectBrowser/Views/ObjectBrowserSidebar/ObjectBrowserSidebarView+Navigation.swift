import SwiftUI

extension ObjectBrowserSidebarView {
    internal func selectSession(_ session: ConnectionSession) {
        selectedConnectionID = session.connection.id
        environmentState.sessionCoordinator.setActiveSession(session.id)
        viewModel.ensureServerExpanded(for: session.connection.id, sessions: sessions)
    }

    internal func handleDatabaseSelection(_ databaseName: String, in session: ConnectionSession) {
        Task { @MainActor in
            await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
            selectedConnectionID = session.connection.id
            viewModel.ensureServerExpanded(for: session.connection.id, sessions: sessions)
            viewModel.resetFilters(for: session, selectedSession: selectedSession)
        }
    }

    internal func syncSelectionWithSessions(proxy: ScrollViewProxy? = nil) {
        viewModel.expandedServerIDs = viewModel.expandedServerIDs.filter { id in sessions.contains { $0.connection.id == id } }
        let currentIDs = Set(sessions.map { $0.connection.id })
        let newIDs = currentIDs.subtracting(viewModel.knownSessionIDs)
        if viewModel.knownSessionIDs.isEmpty && !currentIDs.isEmpty {
            // Auto-expand all servers on first connection
            viewModel.expandedServerIDs.formUnion(currentIDs)
        } else if !newIDs.isEmpty {
            // Auto-expand and select newly connected servers
            viewModel.expandedServerIDs.formUnion(newIDs)
            if let newID = newIDs.first {
                selectedConnectionID = newID
                if let proxy {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newID, anchor: .top)
                        }
                    }
                }
            }
        }
        viewModel.knownSessionIDs = currentIDs
        if selectedConnectionID == nil || !sessions.contains(where: { $0.connection.id == selectedConnectionID }) {
            selectedConnectionID = sessions.first?.connection.id
        }
        if let id = selectedConnectionID {
            viewModel.ensureServerExpanded(for: id, sessions: sessions)
        }
    }

    internal func refreshSelectedSessionStructure() async {
        guard let session = selectedSession else { return }
        await environmentState.refreshDatabaseStructure(for: session.id)
    }
}
