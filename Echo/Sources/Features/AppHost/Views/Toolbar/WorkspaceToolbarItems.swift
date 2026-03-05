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

    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appearanceStore: AppearanceStore

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
                    environmentState.openQueryTab()
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

    // MARK: - Trailing Actions (iOS)

    private var trailingActions: some View {
        HStack(spacing: 12) {
            RefreshToolbarButton()
                .labelStyle(.iconOnly)

            Button {
                environmentState.openQueryTab()
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
        .padding(.horizontal, SpacingTokens.xxxs)
        .fixedSize()
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
}
