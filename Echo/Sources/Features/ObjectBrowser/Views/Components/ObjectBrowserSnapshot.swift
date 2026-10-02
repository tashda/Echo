import Foundation

@MainActor
enum ObjectBrowserSnapshotBuilder {
    static func buildRoots(
        pendingConnections: [PendingConnection],
        sessions: [ConnectionSession],
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> [ObjectBrowserNode] {
        // Kept minimal so the first server card lines up with the top of the rail.
        let topSpacer = ObjectBrowserNode(
            id: "explorer-lab#top-spacer",
            row: .topSpacer(SpacingTokens.micro)
        )
        // Round 51, SH5: a minimized card is not in the list at all; its server stays in the rail.
        let minimized = viewModel.minimizedServers(sessions: sessions)

        var rows: [ObjectBrowserNode] = [topSpacer]
        // Each server sits on its own card; cards are one gutter apart (the Spacing Between
        // Panes setting), plus the room left below a card's last row.
        let cardSpacing = settings.workspaceGutter.points + LayoutTokens.Workspace.treeCardBottomPadding
        func appendGap(before key: String) {
            guard rows.count > 1 else { return }
            rows.append(ObjectBrowserNode(id: "explorer-lab#gap#\(key)", row: .topSpacer(cardSpacing)))
        }

        for session in sessions where !minimized.isMinimized(session.connection.id) {
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
        default:
            // Folders first (round 16): while the server's structure loads, its sections are
            // already there and Databases says it is loading.
            let isLoadingServer: Bool = switch session.structureLoadingState {
            case .idle: true
            case .loading: session.databaseStructure == nil
            default: false
            }
            let builder = ExplorerBlueprintWalker(session: session, settings: settings, viewModel: viewModel, isLoadingServer: isLoadingServer)
            return builder.nodes(
                for: ExplorerBlueprint.blueprint(for: session.connection.databaseType).server,
                in: .server
            )
        }
    }
}
