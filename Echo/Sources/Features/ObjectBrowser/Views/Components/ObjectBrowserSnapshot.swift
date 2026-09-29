import Foundation

@MainActor
enum ObjectBrowserSnapshotBuilder {
    static func buildRoots(
        pendingConnections: [PendingConnection],
        sessions: [ConnectionSession],
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel,
        selectedConnectionID: UUID? = nil
    ) -> [ObjectBrowserNode] {
        let connectionLayoutMode = ObjectBrowserConnectionLayoutMode(
            expandOneConnectionAtATime: settings.sidebarExpandOneConnectionAtATime
        )
        let topSpacer = ObjectBrowserNode(
            id: "explorer-lab#top-spacer",
            row: .topSpacer(connectionLayoutMode.outlineTopSpacerHeight)
        )

        var rows: [ObjectBrowserNode] = [topSpacer]
        // Each server sits on its own card; cards are one gutter apart (the Spacing Between
        // Panes setting), plus the room left below a card's last row.
        let cardSpacing = settings.workspaceGutter.points + LayoutTokens.Workspace.treeCardBottomPadding
        func appendGap(before key: String) {
            guard rows.count > 1 else { return }
            rows.append(ObjectBrowserNode(id: "explorer-lab#gap#\(key)", row: .topSpacer(cardSpacing)))
        }

        if !connectionLayoutMode.showsServerNameInOutline,
           let activeSession = selectedSession(from: sessions, selectedConnectionID: selectedConnectionID) {
            rows.append(contentsOf: serverChildren(
                for: activeSession,
                settings: settings,
                viewModel: viewModel
            ))
        } else {
            for session in sessions {
                appendGap(before: session.connection.id.uuidString)
                let serverID = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: session.connection.id)
                rows.append(
                    ObjectBrowserNode(
                        id: serverID,
                        row: .server(session),
                        children: serverChildren(
                            for: session,
                            settings: settings,
                            viewModel: viewModel
                        )
                    )
                )
            }
        }

        // Servers still connecting, or that failed to, come last, in the rail's order.
        for pending in pendingConnections {
            appendGap(before: "pending#\(pending.id.uuidString)")
            rows.append(
                ObjectBrowserNode(
                    id: "\(pending.id.uuidString)#pending",
                    row: .pendingConnection(pending)
                )
            )
        }

        return rows
    }

    private static func selectedSession(
        from sessions: [ConnectionSession],
        selectedConnectionID: UUID?
    ) -> ConnectionSession? {
        if let selectedConnectionID,
           let selected = sessions.first(where: { $0.connection.id == selectedConnectionID }) {
            return selected
        }
        return sessions.first
    }

    static func serverChildren(
        for session: ConnectionSession,
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> [ObjectBrowserNode] {
        let connectionID = session.connection.id.uuidString
        switch session.structureLoadingState {
        case .failed(let message):
            return [ObjectBrowserNode(
                id: "\(connectionID)#failed",
                row: .message(message ?? "Failed to load", systemImage: "exclamationmark.triangle.fill")
            )]
        case .idle:
            return [ObjectBrowserNode(id: "\(connectionID)#server-loading", row: .loading("Loading server"))]
        case .loading where session.databaseStructure == nil:
            return [ObjectBrowserNode(id: "\(connectionID)#server-loading", row: .loading("Loading server"))]
        default:
            let builder = ExplorerBlueprintWalker(session: session, settings: settings, viewModel: viewModel)
            return builder.nodes(
                for: ExplorerBlueprint.blueprint(for: session.connection.databaseType).server,
                in: .server
            )
        }
    }
}
