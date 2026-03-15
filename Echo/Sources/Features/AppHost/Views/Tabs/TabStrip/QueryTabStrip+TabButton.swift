import SwiftUI

extension QueryTabStrip {
    @ViewBuilder
    func tabButtonView(tab: WorkspaceTab, targetWidth: CGFloat, index: Int, totalCount: Int, appearance: TabChromePalette?) -> some View {
        let isActive = tabStore.activeTabId == tab.id
        let tabIndex = tabStore.index(of: tab.id) ?? 0
        let hasLeft = tabIndex > 0
        let hasRight = tabIndex < totalCount - 1
        let canDuplicate = tab.kind == .query
        let closeOthersDisabled = totalCount <= 1
        let isBeingDragged = dragState.isActive && dragState.id == tab.id
        let databases = resolveDatabaseNames(for: tab)

        QueryTabButton(
            tab: tab,
            isActive: isActive,
            onSelect: { tabStore.activeTabId = tab.id },
            onClose: { tabStore.closeTab(id: tab.id) },
            onAddBookmark: tab.query == nil ? nil : { bookmark(tab: tab) },
            onPinToggle: { tabStore.togglePin(for: tab.id) },
            onDuplicate: { environmentState.duplicateTab(tab) },
            onCloseOthers: { tabStore.closeOtherTabs(keeping: tab.id) },
            onCloseLeft: { tabStore.closeTabsLeft(of: tab.id) },
            onCloseRight: { tabStore.closeTabsRight(of: tab.id) },
            canDuplicate: canDuplicate,
            closeOthersDisabled: closeOthersDisabled,
            closeTabsLeftDisabled: !hasLeft,
            closeTabsRightDisabled: !hasRight,
            isDropTarget: false,
            isBeingDragged: isBeingDragged,
            appearance: appearance,
            onHoverChanged: { hovering in
                if hovering {
                    hoveredTabID = tab.id
                } else if hoveredTabID == tab.id {
                    hoveredTabID = nil
                }
            },
            availableDatabases: databases,
            onSwitchDatabase: databases.isEmpty ? nil : { dbName in
                switchDatabase(dbName, for: tab)
            }
        )
        .frame(width: targetWidth > 0 ? targetWidth : nil)
        .id(tab.id)
        .transaction { transaction in
            if isBeingDragged {
                transaction.animation = nil
            }
        }
    }

    func bookmark(tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        let trimmed = queryState.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let database = queryState.clipboardMetadata.databaseName ?? tab.connection.database
        Task {
            await environmentState.addBookmark(
                for: tab.connection,
                databaseName: database,
                title: tab.title,
                query: trimmed,
                source: .tab
            )
        }
    }

    // MARK: - Database Switching

    func resolveDatabaseNames(for tab: WorkspaceTab) -> [String] {
        guard tab.kind == .query else { return [] }
        guard let session = environmentState.sessionCoordinator.activeSessions.first(where: { $0.id == tab.connectionSessionID }) else { return [] }
        let databases = session.databaseStructure?.databases ?? []
        return databases.filter(\.isOnline).map(\.name).sorted()
    }

    func switchDatabase(_ databaseName: String, for tab: WorkspaceTab) {
        let dbType = tab.connection.databaseType

        switch dbType {
        case .microsoftSQL, .mysql:
            // Execute USE on the existing connection
            Task {
                do {
                    _ = try await tab.session.sessionForDatabase(databaseName)
                    await MainActor.run {
                        tab.activeDatabaseName = databaseName
                        if let queryState = tab.query {
                            queryState.updateClipboardContext(
                                serverName: queryState.clipboardMetadata.serverName,
                                databaseName: databaseName,
                                connectionColorHex: queryState.clipboardMetadata.connectionColorHex
                            )
                        }
                        if let session = environmentState.sessionCoordinator.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
                            session.selectedDatabaseName = databaseName
                        }
                        environmentState.notificationEngine?.post(category: .databaseSwitched, message: "Switched to \(databaseName)")
                    }
                } catch {
                    await MainActor.run {
                        environmentState.notificationEngine?.post(category: .databaseSwitchFailed, message: "Failed to switch: \(error.localizedDescription)", duration: 5.0)
                    }
                }
            }

        case .postgresql:
            // PostgreSQL needs a new session per database
            Task {
                do {
                    let newSession = try await tab.session.sessionForDatabase(databaseName)
                    await MainActor.run {
                        tab.activeDatabaseName = databaseName
                        if let queryState = tab.query {
                            queryState.updateClipboardContext(
                                serverName: queryState.clipboardMetadata.serverName,
                                databaseName: databaseName,
                                connectionColorHex: queryState.clipboardMetadata.connectionColorHex
                            )
                        }
                        // For PostgreSQL, we can't swap the tab's session (it's `let`),
                        // so we update the connection session's selected database.
                        // The next query execution will use the correct session
                        // via the USE prepend logic for MSSQL, or for PG the session
                        // itself is already connected to the right database.
                        if let connSession = environmentState.sessionCoordinator.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
                            connSession.selectedDatabaseName = databaseName
                        }
                        _ = newSession // Session is cached in PostgresServerConnection
                        environmentState.notificationEngine?.post(category: .databaseSwitched, message: "Switched to \(databaseName)")
                    }
                } catch {
                    await MainActor.run {
                        environmentState.notificationEngine?.post(category: .databaseSwitchFailed, message: "Failed to switch: \(error.localizedDescription)", duration: 5.0)
                    }
                }
            }

        case .sqlite:
            break
        }
    }
}
