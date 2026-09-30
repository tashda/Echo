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
    @Environment(\.echoMotion) private var motion

    var showsTabStrip: Bool = true
    var tabBarLeadingPadding: CGFloat = 6
    var tabBarTrailingPadding: CGFloat = 6

    private var recentConnectionItems: [RecentConnectionItem] {
        environmentState.recentConnections.compactMap { record in
            guard let connection = connectionStore.connections.first(where: { $0.id == record.id }) else {
                return nil
            }

            let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return RecentConnectionItem(
                id: record.identifier,
                record: record,
                name: trimmedName.isEmpty ? connection.host : trimmedName,
                server: connection.host,
                lastConnectedAt: record.lastUsedAt,
                color: connection.color
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
        // Cards are for content: with no tab open, the welcome (or the active server's page) sits
        // straight on the canvas, and the strip and card grow in once a tab opens.
        let showsCanvasPage = tabStore.tabs.isEmpty && !appState.showTabOverview
        let activeSession = environmentState.sessionGroup.activeSession

        Group {
            if showsCanvasPage, let activeSession {
                ConnectionDashboardView(session: activeSession)
                    .id(activeSession.id)
                    .transition(.opacity)
            } else if showsCanvasPage {
                WorkspaceWelcomeView(
                    recents: Array(recentConnectionItems.prefix(WorkspaceWelcomeView.maximumRecentCount)),
                    onSelectRecent: connectToRecentConnection
                )
                .transition(.opacity)
            } else {
                VStack(spacing: max(gutter - stripInset, SpacingTokens.none)) {
                    if showsTabStrip {
                        QueryTabStrip(
                            leadingPadding: tabBarLeadingPadding,
                            trailingPadding: tabBarTrailingPadding
                        )
                    }

                    // Tab content sits on an opaque card below the strip (Design/02-layout.md › Cards);
                    // query tabs draw two, editor over results.
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
                            .workspaceCard()
                            // The overview zooms in from the tab, and the tab zooms back out of it (plan O3).
                            .transition(.scale(scale: 1.04).combined(with: .opacity))
                        } else {
                            activeTabContainer
                                .transition(.scale(scale: 0.94).combined(with: .opacity))
                        }
                    }
                    .animation(motion.standard, value: appState.showTabOverview)
                    .simultaneousGesture(overviewPinch)
                    // A zero minimum keeps tall content (a long list, a big dashboard) from pushing
                    // the window past its own edges; the card clips it instead.
                    .frame(minWidth: SpacingTokens.none, maxWidth: .infinity, minHeight: SpacingTokens.none, maxHeight: .infinity)
                    // Toasts sit in the top-right corner of the tab's first card, below the tab
                    // bar: inside the editor card on a query tab (round 15).
                    .toastOverlay()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(minWidth: SpacingTokens.none, maxWidth: .infinity, minHeight: SpacingTokens.none, maxHeight: .infinity)
        .toastOverlay(isActive: showsCanvasPage)
        .animation(motion.standard, value: showsCanvasPage)
        .animation(.easeInOut(duration: 0.2), value: appState.showTabOverview)
        .onChange(of: tabStore.activeTabId) { _, _ in
            if appState.showTabOverview {
                appState.showTabOverview = false
            }
        }
    }

    /// Keeps the few most recent tabs mounted so switching back is instant (round 9, TFIX); a
    /// window hosting a single detached tab mounts just that one.
    @ViewBuilder
    private var activeTabContainer: some View {
        if let currentWorkspaceTab {
            if hostedWorkspaceTabID != nil {
                tabContent(currentWorkspaceTab)
            } else {
                KeptAliveTabsView(tabs: tabStore.tabs, activeTab: currentWorkspaceTab) { tab in
                    tabContent(tab)
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: WorkspaceTab) -> some View {
        let content = WorkspaceContentView(
            tab: tab,
            runQuery: { sql in await runQuery(tabId: tab.id, sql: sql) },
            gridStateProvider: { tab.resultsGridState }
        )
        .id(tab.id)
        if tab.drawsOwnCards {
            content
        } else if tab.kind.isToolTab {
            ToolTabContainer(tab: tab) { content }
        } else {
            content.workspaceCard()
        }
    }

    private func connectToRecentConnection(_ item: RecentConnectionItem) {
        guard let connection = connectionStore.connections.first(where: { $0.id == item.record.id }) else { return }
        environmentState.connect(to: connection)
    }
}
