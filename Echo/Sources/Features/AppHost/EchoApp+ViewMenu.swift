//
//  EchoApp+ViewMenu.swift
//  Echo
//

import SwiftUI
#if os(macOS)
import AppKit

struct ViewMenuCommands: Commands {
    var appState: AppState
    let environmentState: EnvironmentState
    let navigationStore: NavigationStore
    let tabStore: TabStore

    var body: some Commands {
        // Replaces the system's sidebar item, which would otherwise take ⌃⌘S and send it to a
        // split view the workspace no longer has.
        CommandGroup(replacing: .sidebar) {
            Button {
                let keyWindow = NSApplication.shared.keyWindow
                if keyWindow?.identifier == AppWindowIdentifier.workspace {
                    // The workspace draws its own tree beside the rail; the shell animates it.
                    let hasContent = WorkspaceTreeAvailability.hasContent(
                        environmentState: environmentState,
                        navigationStore: navigationStore
                    )
                    guard hasContent else { return }
                    appState.isWorkspaceTreeVisible.toggle()
                } else if keyWindow?.identifier == AppWindowIdentifier.manageConnections {
                    NotificationCenter.default.post(name: .toggleManageConnectionsSidebar, object: nil)
                } else {
                    NSApp?.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button {
                appState.toggleInspector()
            } label: {
                Label(
                    appState.showInfoSidebar && !appState.isNotificationHistoryVisible ? "Hide Inspector" : "Show Inspector",
                    systemImage: "sidebar.trailing"
                )
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(!navigationStore.isWorkspaceWindowKey)

            Button("Bookmarks", systemImage: "bookmark") { appState.showInspectorPage(.bookmarks) }
                .disabled(!navigationStore.isWorkspaceWindowKey)
            Button("Query History", systemImage: "clock") { appState.showInspectorPage(.history) }
                .disabled(!navigationStore.isWorkspaceWindowKey)

            Button {
                tabStore.activeTab?.panelState.isOpen.toggle()
            } label: {
                let isOpen = tabStore.activeTab?.panelState.isOpen ?? false
                Label(
                    isOpen ? "Hide Bottom Panel" : "Show Bottom Panel",
                    systemImage: "rectangle.bottomhalf.inset.filled"
                )
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
            .disabled(!navigationStore.isWorkspaceWindowKey || !tabStore.hasTabs)

            // Same as double-clicking the gap between the content and panel cards (plan E3, TT1).
            Button {
                guard let panelState = tabStore.activeTab?.panelState else { return }
                if !panelState.isOpen {
                    panelState.isOpen = true
                    panelState.isResultsMaximized = true
                } else {
                    panelState.isResultsMaximized.toggle()
                }
            } label: {
                let isMaximized = tabStore.activeTab?.panelState.isResultsMaximized ?? false
                let isQuery = tabStore.activeTab?.kind == .query
                Label(
                    isMaximized ? (isQuery ? "Restore Editor" : "Restore Bottom Panel") : (isQuery ? "Maximize Results" : "Maximize Bottom Panel"),
                    systemImage: isMaximized ? "rectangle.split.1x2" : "rectangle.bottomhalf.filled"
                )
            }
            .keyboardShortcut("y", modifiers: [.command, .shift, .option])
            .disabled(!navigationStore.isWorkspaceWindowKey || tabStore.activeTab?.kind.hasBottomPanel != true)

            // Search is the ⌘K palette (plan K4); ⇧⌘F is Format Query (K3).
            Button {
                appState.isCommandPaletteVisible = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(!navigationStore.isWorkspaceWindowKey)

            Button {
                appState.isCommandPaletteVisible.toggle()
            } label: {
                Label("Command Palette", systemImage: "command")
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(!navigationStore.isWorkspaceWindowKey)

            Divider()

            // Round 35.1 (TO6): the tab overview is the ⌘K palette showing this window's tabs.
            Button {
                appState.toggleTabOverview()
            } label: {
                Label(
                    appState.isTabOverviewVisible ? "Hide Tab Overview" : "Show Tab Overview",
                    systemImage: "square.grid.2x2"
                )
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(!navigationStore.isWorkspaceWindowKey || !tabStore.hasTabs)

            // Round 34 (KR0): ⌘R reloads the front tool tab, as Refresh in the toolbar does.
            Button {
                guard let tab = reloadableTab else { return }
                environmentState.tabReloader.reload(tab, environmentState: environmentState)
            } label: {
                Label("Reload Tab", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(reloadableTab == nil)

            Divider()

            // Round 28.8 (ZK0): the query editor's zoom, this tab only.
            Button("Zoom In", systemImage: "plus.magnifyingglass") { zoomEditor(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(editorQuery == nil)
            Button("Zoom Out", systemImage: "minus.magnifyingglass") { zoomEditor(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(editorQuery == nil)
            Button("Actual Size", systemImage: "1.magnifyingglass") { editorQuery?.editorZoom = EditorZoom.actualSize }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(editorQuery == nil)
        }
    }

    private var reloadableTab: WorkspaceTab? {
        guard navigationStore.isWorkspaceWindowKey, let tab = tabStore.activeTab, TabReloader.canReload(tab.kind) else { return nil }
        return tab
    }

    private var editorQuery: QueryEditorState? {
        guard navigationStore.isWorkspaceWindowKey else { return nil }
        return tabStore.activeTab?.query
    }

    private func zoomEditor(by direction: Int) {
        guard let query = editorQuery else { return }
        query.editorZoom = EditorZoom.step(query.editorZoom, by: direction)
    }
}
#endif
