import SwiftUI
import Foundation
import UniformTypeIdentifiers
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
func tabHairlineWidth() -> CGFloat {
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    return max(1.0 / scale, 0.5)
}
#else
func tabHairlineWidth() -> CGFloat { 1 }
#endif

struct WorkspaceTabContainerView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(TabStore.self) var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(\.hostedWorkspaceTabID) private var hostedWorkspaceTabID

    var showsTabStrip: Bool = true
    var tabBarLeadingPadding: CGFloat = 6
    var tabBarTrailingPadding: CGFloat = 6

    private var recentConnectionItems: [RecentConnectionItem] {
        environmentState.recentConnections.compactMap { record in
            guard let connection = connectionStore.connections.first(where: { $0.id == record.id }) else {
                return nil
            }

            let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = trimmedName.isEmpty ? connection.host : trimmedName
            let database = record.databaseName

            let settings = projectStore.globalSettings
            return RecentConnectionItem(
                id: record.identifier,
                record: record,
                name: displayName,
                server: connection.host,
                database: database,
                lastConnectedAt: record.lastUsedAt,
                databaseType: connection.databaseType,
                connectionColorHex: connection.metadataColorHex,
                accentColorSource: settings.accentColorSource,
                customAccentColorHex: settings.customAccentColorHex
            )
        }
    }

    private var currentWorkspaceTab: WorkspaceTab? {
        if let hostedWorkspaceTabID,
           let hostedTab = tabStore.tabs.first(where: { $0.id == hostedWorkspaceTabID }) {
            return hostedTab
        }

        return tabStore.activeTab
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabStrip {
                QueryTabStrip(
                    leadingPadding: tabBarLeadingPadding,
                    trailingPadding: tabBarTrailingPadding
                )
            }

            if appState.showTabOverview {
                TabOverviewView(
                    tabs: tabStore.tabs,
                    activeTabId: tabStore.activeTabId,
                    onSelectTab: { tabId in
                        tabStore.activeTabId = tabId
                        appState.showTabOverview = false
                    },
                    onCloseTab: { tabId in
                        tabStore.closeTab(id: tabId)
                    }
                )
            } else if !tabStore.tabs.isEmpty {
                aliveTabsContainer
            } else if let activeSession = environmentState.sessionGroup.activeSession {
                ConnectionDashboardView(session: activeSession)
            } else {
                RecentConnectionsPlaceholder(
                    connections: recentConnectionItems,
                    onSelectConnection: connectToRecentConnection
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.showTabOverview)
        .onChange(of: tabStore.activeTabId) { _, _ in
            if appState.showTabOverview {
                appState.showTabOverview = false
            }
        }
    }

    /// Keeps all tab views alive in a ZStack. The active tab is fully visible and
    /// interactive; inactive tabs are hidden (opacity 0) but their NSViews persist
    /// in memory, so switching is instant — no view teardown/rebuild.
    @ViewBuilder
    private var aliveTabsContainer: some View {
        if let hostedWorkspaceTabID,
           let hostedTab = tabStore.tabs.first(where: { $0.id == hostedWorkspaceTabID }) {
            // Detached window: show only the hosted tab
            WorkspaceContentView(
                tab: hostedTab,
                runQuery: { sql in await runQuery(tabId: hostedTab.id, sql: sql) },
                gridStateProvider: { hostedTab.resultsGridState }
            )
        } else {
            let activeId = tabStore.activeTabId
            ZStack {
                ForEach(tabStore.tabs) { tab in
                    let isActive = tab.id == activeId
                    WorkspaceContentView(
                        tab: tab,
                        runQuery: { sql in await runQuery(tabId: tab.id, sql: sql) },
                        gridStateProvider: { tab.resultsGridState }
                    )
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
                }
            }
        }
    }

    private func connectToRecentConnection(_ item: RecentConnectionItem) {
        guard let connection = connectionStore.connections.first(where: { $0.id == item.record.id }) else { return }
        environmentState.connect(to: connection)
    }
}
