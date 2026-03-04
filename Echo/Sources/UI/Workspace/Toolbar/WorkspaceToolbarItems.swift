import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import EchoSense

struct WorkspaceToolbarItems: ToolbarContent {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @Environment(TabStore.self) internal var tabStore
    
    @EnvironmentObject internal var workspaceSessionStore: WorkspaceSessionStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some ToolbarContent {
#if os(macOS)
        macToolbar
#else
        iosToolbar
#endif
    }

#if os(macOS)
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        ToolbarItem(id: "workspace.navigation.project", placement: .navigation) {
            projectMenu
        }

        ToolbarItem(id: "workspace.primary.refresh", placement: .primaryAction) {
            toolbarIconButton {
                RefreshToolbarButton()
                    .labelStyle(.iconOnly)
            }
        }

        ToolbarItem(id: "workspace.primary.newtab", placement: .primaryAction) {
            toolbarIconButton {
                Button {
                    workspaceSessionStore.openQueryTab()
                } label: {
                    Label("New Tab", systemImage: "plus")
                }
                .help("Open a new query tab")
                .disabled(!canOpenNewTab)
                .labelStyle(.iconOnly)
                .accessibilityLabel("New Tab")
            }
        }

        ToolbarItem(id: "workspace.primary.taboverview", placement: .primaryAction) {
            toolbarIconButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showTabOverview.toggle()
                    }
                } label: {
                    Label(
                        appState.showTabOverview ? "Hide Tab Overview" : "Tab Overview",
                        systemImage: appState.showTabOverview ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2"
                    )
                }
                .help(appState.showTabOverview ? "Hide Tab Overview" : "Show all tabs")
                .disabled(tabStore.tabs.isEmpty)
                .labelStyle(.iconOnly)
                .accessibilityLabel(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview")
            }
        }

        ToolbarItem(id: "workspace.primary.toggleinspector", placement: .primaryAction) {
            toolbarIconButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showInfoSidebar.toggle()
                    }
                } label: {
                    Label(
                        appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector",
                        systemImage: appState.showInfoSidebar ? "sidebar.trailing" : "sidebar.right"
                    )
                }
                .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
                .labelStyle(.iconOnly)
                .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
            }
        }
    }
#else
    @ToolbarContentBuilder
    private var iosToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            projectMenu
        }

        let showConnectionControls = false
        if showConnectionControls {
            ToolbarItemGroup(placement: .navigation) {
                connectionsMenu
                databaseMenu
            }
        }

        ToolbarItem(placement: .primaryAction) {
            trailingActions
        }
    }
#endif

    // MARK: - Toolbar Buttons

    private var trailingActions: some View {
        HStack(spacing: 12) {
            RefreshToolbarButton()
                .labelStyle(.iconOnly)

            Button {
                workspaceSessionStore.openQueryTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
            .help("Open a new query tab")
            .disabled(!canOpenNewTab)
            .labelStyle(.iconOnly)
            .accessibilityLabel("New Tab")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showTabOverview.toggle()
                }
            } label: {
                Label(
                    appState.showTabOverview ? "Hide Tab Overview" : "Tab Overview",
                    systemImage: appState.showTabOverview ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2"
                )
            }
            .help(appState.showTabOverview ? "Hide Tab Overview" : "Show all tabs")
            .disabled(tabStore.tabs.isEmpty)
            .labelStyle(.iconOnly)
            .accessibilityLabel(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showInfoSidebar.toggle()
                }
            } label: {
                Label(
                    appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector",
                    systemImage: appState.showInfoSidebar ? "sidebar.trailing" : "sidebar.right"
                )
            }
            .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
            .labelStyle(.iconOnly)
            .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
        }
        .padding(.horizontal, 2)
        .fixedSize()
    }

    // MARK: - Helpers

    internal var canOpenNewTab: Bool {
        activeSession != nil
    }

    internal var activeSession: ConnectionSession? {
        if let connection = navigationStore.navigationState.selectedConnection,
           let session = workspaceSessionStore.sessionManager.sessionForConnection(connection.id) {
            return session
        }
        return workspaceSessionStore.sessionManager.activeSession ?? workspaceSessionStore.sessionManager.activeSessions.first
    }

    private func hasActiveDatabase(for session: ConnectionSession) -> Bool {
        func normalized(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        if normalized(navigationStore.navigationState.selectedDatabase) != nil { return true }
        if normalized(session.selectedDatabaseName) != nil { return true }
        return normalized(session.connection.database) != nil
    }

    internal func availableDatabases(in session: ConnectionSession) -> [DatabaseInfo]? {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return nil
    }

    internal func selectDatabase(_ database: String, in session: ConnectionSession) {
        Task {
            await workspaceSessionStore.loadSchemaForDatabase(database, connectionSession: session)
            await MainActor.run {
                navigationStore.navigationState.selectDatabase(database)
            }
        }
    }

    internal func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let hostTrimmed = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return hostTrimmed.isEmpty ? "Untitled Connection" : hostTrimmed
    }

    internal var currentServerTitle: String {
        if let connection = navigationStore.navigationState.selectedConnection {
            let display = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return display.isEmpty ? connection.host : display
        }
        return "Server"
    }

    internal var currentDatabaseTitle: String {
        navigationStore.navigationState.selectedDatabase ?? "Database"
    }

    internal var projectIcon: ToolbarIcon { .system("folder.badge.person.crop") }

    internal var currentServerIcon: ToolbarIcon {
        if let connection = navigationStore.navigationState.selectedConnection {
            return connectionIcon(for: connection)
        }
        return .system("externaldrive")
    }

    internal func connectionIcon(for connection: SavedConnection) -> ToolbarIcon {
        let assetName = connection.databaseType.iconName
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        return .system("externaldrive")
    }

    internal func databaseToolbarIcon(isSelected: Bool) -> ToolbarIcon {
        let assetName = isSelected ? "database.check.outlined" : "database.outlined"
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        let fallbackName = isSelected ? "checkmark.circle" : "cylinder.split.1x2"
        return .system(fallbackName)
    }

    internal var databaseMenuIcon: ToolbarIcon {
        if hasImage(named: "database.outlined") {
            return .asset("database.outlined", isTemplate: false)
        }
        return .system("cylinder")
    }

    @ViewBuilder
    internal func toolbarButtonLabel(icon: ToolbarIcon, title: String) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

#if os(macOS)
    @ViewBuilder
    private func toolbarIconButton<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: WorkspaceChromeMetrics.toolbarTabBarHeight,
                   height: WorkspaceChromeMetrics.toolbarTabBarHeight)
            .contentShape(Rectangle())
    }

#endif

    @ViewBuilder
    internal func menuRow(icon: ToolbarIcon, title: String, isSelected: Bool = false) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(.system(size: 13, weight: .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    internal func toolbarIconView(_ icon: ToolbarIcon) -> some View {
        icon.image
            .renderingMode(icon.isTemplate ? .template : .original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .cornerRadius(icon.isTemplate ? 0 : 3)
    }

    private func hasImage(named name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(named: name) != nil
        #elseif canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
