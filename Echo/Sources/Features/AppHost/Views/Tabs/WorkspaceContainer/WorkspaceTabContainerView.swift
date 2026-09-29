import SwiftUI
import Foundation
import UniformTypeIdentifiers
import EchoSense
#if os(macOS)
import AppKit
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
            ?? tabStore.tabs.first
    }

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points
        // The strip keeps a little room above and below its plate; the gutter covers the rest,
        // so the visible gap between the plate and the card is the gutter.
        let stripInset = (WorkspaceChromeMetrics.tabStripTotalHeight - WorkspaceChromeMetrics.chromeBackgroundHeight) / 2

        VStack(spacing: max(gutter - stripInset, SpacingTokens.none)) {
            if showsTabStrip {
                QueryTabStrip(
                    leadingPadding: tabBarLeadingPadding,
                    trailingPadding: tabBarTrailingPadding
                )
            }

            // Tab content sits on one opaque card below the strip (Design/02-layout.md › Cards).
            Group {
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
                    activeTabContainer
                } else if let activeSession = environmentState.sessionGroup.activeSession {
                    ConnectionDashboardView(session: activeSession)
                } else {
                    RecentConnectionsPlaceholder(
                        connections: Array(recentConnectionItems.prefix(RecentConnectionsPlaceholder.maximumCount)),
                        onSelectConnection: connectToRecentConnection
                    )
                }
            }
            // A zero minimum keeps tall content (a long list, a big dashboard) from pushing the
            // window past its own edges; the card clips it instead.
            .frame(minWidth: SpacingTokens.none, maxWidth: .infinity, minHeight: SpacingTokens.none, maxHeight: .infinity)
            .workspaceCard()
        }
        .animation(.easeInOut(duration: 0.2), value: appState.showTabOverview)
        .onChange(of: tabStore.activeTabId) { _, _ in
            if appState.showTabOverview {
                appState.showTabOverview = false
            }
        }
    }

    /// Mounts only the visible tab. WorkspaceTab and QueryEditorState keep query,
    /// result, and grid state alive without keeping inactive SwiftUI/AppKit trees
    /// in the resize and observation paths.
    @ViewBuilder
    private var activeTabContainer: some View {
        if let currentWorkspaceTab {
            WorkspaceContentView(
                tab: currentWorkspaceTab,
                runQuery: { sql in await runQuery(tabId: currentWorkspaceTab.id, sql: sql) },
                gridStateProvider: { currentWorkspaceTab.resultsGridState }
            )
            .id(currentWorkspaceTab.id)
        }
    }

    private func connectToRecentConnection(_ item: RecentConnectionItem) {
        guard let connection = connectionStore.connections.first(where: { $0.id == item.record.id }) else { return }
        environmentState.connect(to: connection)
    }
}
