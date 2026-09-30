import AppKit
import SwiftUI

/// The section dock (TC1, round 16): switching sections, the icons' right-click menus, and the
/// dock choices, saved for one server (on its connection) or its whole type (in Settings).
extension ObjectBrowserSidebarView {
    /// What the dock's buttons and menus call back into.
    func dockActions(builtRoots: [ObjectBrowserNode]) -> ExplorerDockActions {
        ExplorerDockActions(
            select: { connectionID, itemID in selectDockSection(itemID, connectionID: connectionID, builtRoots: builtRoots) },
            menu: { connectionID, itemID in dockMenu(connectionID: connectionID, itemID: itemID, builtRoots: builtRoots) }
        )
    }

    /// Switching a server's dock section (round 19, S3 and jump), as one choreography:
    /// 1. a veil in the card's colour fades in over the rows (ExplorerTreeVeilLayer);
    /// 2. under it, the new section swaps in with no row transitions and its rows stay invisible
    ///    while the card's edge moves to the new size (`dockEdge`), so no row shows outside the
    ///    card; the outline returns to where this section was scrolled, if anywhere;
    /// 3. the rows appear under the veil, and the veil fades out.
    /// Only the veil and the card's edge animate, so the switch costs almost nothing per frame.
    func selectDockSection(_ itemID: String, connectionID: UUID, builtRoots: [ObjectBrowserNode]) {
        guard let (server, session) = serverNode(connectionID, in: builtRoots),
              let layout = ExplorerDock.layout(for: server.children, session: session, saved: savedDockKeys(for: session))
        else { return }
        let current = ExplorerDock.selectedID(in: layout, connectionID: connectionID, saved: viewModel.dockSelection(for: connectionID))
        guard current != itemID, !viewModel.dockSwitchingConnectionIDs.contains(connectionID) else { return }
        ExplorerMotionLog.mark("dock switch requested", connectionID)

        let timing = ExplorerDockSwitchTiming(motion: motion)
        WindowDragPause.pauseWorkspace(for: timing.totalDuration + 0.1)
        // Open the section now, while the old rows fade: it shows nothing until it is selected, it
        // starts loading sooner, and the swap then changes one thing instead of two.
        if let section = ExplorerDock.section(for: itemID, in: builtRoots) {
            handleExpansionChange(of: section, isExpanded: true, animated: false)
        }
        withAnimation(timing.fadeOut) {
            _ = viewModel.dockSwitchingConnectionIDs.insert(connectionID)
            _ = viewModel.dockFadingConnectionIDs.insert(connectionID)
        } completion: {
            ExplorerMotionLog.mark("dock switch swap", connectionID)
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                _ = viewModel.dockHiddenRowsConnectionIDs.insert(connectionID)
            }
            withAnimation(motion.dockEdge) {
                viewModel.setDockSelection(itemID, for: connectionID)
            } completion: {
                withTransaction(still) {
                    _ = viewModel.dockHiddenRowsConnectionIDs.remove(connectionID)
                }
                withAnimation(timing.fadeIn) {
                    _ = viewModel.dockFadingConnectionIDs.remove(connectionID)
                } completion: {
                    viewModel.dockSwitchingConnectionIDs.remove(connectionID)
                    ExplorerMotionLog.mark("dock switch done", connectionID)
                }
            }
        }
    }

    /// The server's own dock, or else its type's; nil for the blueprint's default.
    func savedDockKeys(for session: ConnectionSession) -> [String]? {
        let connection = environmentState.connectionStore.connections.first { $0.id == session.connection.id }
        return connection?.explorerDockSections
            ?? projectStore.globalSettings.sidebarDockSections[session.connection.databaseType.rawValue]
    }

    // MARK: - Menus

    /// An icon's menu is its section's own (what right-clicking the folder gave), then Dock; the
    /// empty capsule has Dock alone.
    func dockMenu(connectionID: UUID, itemID: String?, builtRoots: [ObjectBrowserNode]) -> NSMenu {
        guard let (server, session) = serverNode(connectionID, in: builtRoots),
              let layout = ExplorerDock.layout(for: server.children, session: session, saved: savedDockKeys(for: session))
        else { return NSMenu() }

        let menu = itemID.flatMap { ExplorerDock.section(for: $0, in: builtRoots) }.flatMap(contextMenu(for:)) ?? NSMenu()
        if !menu.items.isEmpty { menu.addDivider() }
        _ = menu.addSubmenu("Dock", systemImage: "dock.rectangle") { dock in
            for item in layout.all {
                let entry = dock.addActionItem(item.title, systemImage: item.symbol) {
                    toggleDockSection(item.key, layout: layout, session: session)
                }
                entry.state = layout.shown.contains(item) ? .on : .off
            }
            dock.addDivider()
            dock.addActionItem("Use \(session.connection.databaseType.displayName) Dock", systemImage: "arrow.uturn.backward") {
                saveDock(nil, for: session, scope: .server)
            }
            dock.addActionItem("Customize Dock", systemImage: "slider.horizontal.3") {
                let preferred = ExplorerBlueprint.blueprint(for: session.connection.databaseType).dock?.map(\.rawValue)
                sheetState.dockCustomization = ExplorerDockCustomization(
                    connectionID: connectionID,
                    serverName: session.connection.connectionName.isEmpty ? session.connection.host : session.connection.connectionName,
                    typeName: session.connection.databaseType.displayName,
                    items: layout.all,
                    shownKeys: layout.shown.map(\.key),
                    defaultKeys: ExplorerDock.arrange(keys: layout.all.map(\.key), saved: nil, preferred: preferred).shown
                )
            }
        }
        return menu
    }

    /// Shows or hides one section for this server; the capsule always keeps one.
    private func toggleDockSection(_ key: String, layout: ExplorerDockLayout, session: ConnectionSession) {
        var keys = layout.shown.map(\.key)
        if let index = keys.firstIndex(of: key) {
            guard keys.count > 1 else { return }
            keys.remove(at: index)
        } else {
            keys.append(key)
        }
        saveDock(keys, for: session, scope: .server)
    }

    // MARK: - Saving

    /// Saves a dock for one server (nil follows its type) or for every server of its type.
    func saveDock(_ keys: [String]?, for session: ConnectionSession, scope: ExplorerDockScope) {
        switch scope {
        case .server:
            guard var connection = environmentState.connectionStore.connections.first(where: { $0.id == session.connection.id }) else { return }
            connection.explorerDockSections = keys
            Task { try? await environmentState.connectionStore.updateConnection(connection) }
        case .type:
            var settings = projectStore.globalSettings
            settings.sidebarDockSections[session.connection.databaseType.rawValue] = keys
            Task { try? await projectStore.updateGlobalSettings(settings) }
            // The server follows its type again.
            if environmentState.connectionStore.connections.first(where: { $0.id == session.connection.id })?.explorerDockSections != nil {
                saveDock(nil, for: session, scope: .server)
            }
        }
    }

    func serverNode(_ connectionID: UUID, in roots: [ObjectBrowserNode]) -> (ObjectBrowserNode, ConnectionSession)? {
        for root in roots {
            if case .server(let session) = root.row, session.connection.id == connectionID { return (root, session) }
        }
        return nil
    }
}

/// Where a dock choice is saved.
enum ExplorerDockScope: String, CaseIterable, Identifiable {
    case type
    case server
    var id: String { rawValue }
}
