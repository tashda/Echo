import SwiftUI
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct TabOverviewView: View {
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(TabStore.self) var tabStore

    @Environment(EnvironmentState.self) var environmentState
    @Environment(\.colorScheme) var colorScheme

    @State var animateIn = false
    @State var collapsedServers: Set<UUID> = []
    @State var collapsedDatabases: Set<String> = []
    @State var focusedTabId: UUID?
    @State var lastVisibleTabIDs: [UUID] = []
    @State var draggingTabId: UUID?
    @State var dropTargetTabId: UUID?

    var animation: Animation { .spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2) }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            overviewHero

            if !groupedTabs.isEmpty {
                overviewControls
                    .transition(.opacity)
            }

            ScrollView {
                if groupedTabs.isEmpty {
                    emptyState
                        .padding(.top, 120)
                        .padding(.horizontal, SpacingTokens.xl)
                } else {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.lg) {
                        ForEach(groupedTabs) { serverGroup in
                            serverGroupView(serverGroup)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.xl)
                    .padding(.bottom, SpacingTokens.xxl)
#if os(macOS)
                    Color.clear
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
                            targetTabID: nil,
                            isTrailingPlaceholder: true,
                            tabStore: tabStore,
                            draggingTabId: $draggingTabId,
                            dropTargetTabId: $dropTargetTabId
                        ))
#endif
                }
            }
        }
        .padding(.bottom, SpacingTokens.xl2)
        .background(overviewBackground)
        .onAppear {
            Task {
                triggerAnimation()
                initializeFocus()
            }
        }
        .onDisappear {
            draggingTabId = nil
            dropTargetTabId = nil

            if let active = activeTabId {
                focusedTabId = active
            }
        }
#if os(macOS)
        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
            targetTabID: nil,
            isTrailingPlaceholder: true,
            tabStore: tabStore,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId
        ))
#endif
        .onChange(of: tabs.map(\.id)) { _, ids in
            Task {
                updateFocusForTabChanges(ids: ids)
            }
        }
        .onChange(of: focusedTabId) { _, _ in
            Task {
                ensureFocusedTabVisible()
            }
        }
        .animation(animation, value: animateIn)
    }

    private var overviewBackground: some View {
#if os(macOS)
        let top = Color(nsColor: .windowBackgroundColor)
        let bottom = Color(nsColor: .windowBackgroundColor).opacity(0.97)
#else
        let top = Color(.systemBackground)
        let bottom = Color(.systemBackground)
#endif
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private func triggerAnimation() {
        animateIn = true
    }

    private func initializeFocus() {
        let visible = visibleTabIDs
        lastVisibleTabIDs = visible

        if let active = activeTabId, visible.contains(active) {
            focusedTabId = active
        } else if let firstVisible = visible.first {
            focusedTabId = firstVisible
        } else {
            focusedTabId = tabs.first?.id
        }

        ensureFocusedTabVisible()
    }

    private func ensureFocusedTabVisible() {
        let visible = visibleTabIDs
        lastVisibleTabIDs = visible
        guard let focusedTabId else { return }
        if !visible.contains(focusedTabId) {
            withAnimation(animation) {
                focusedTabIdChanged(focusedTabId)
            }
        }
    }

    private func focusedTabIdChanged(_ tabId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return }
        collapsedServers.remove(tab.connection.id)
        let key = databaseKey(for: tab)
        let identifier = databaseIdentifier(for: key, serverID: tab.connection.id)
        collapsedDatabases.remove(identifier)
        lastVisibleTabIDs = visibleTabIDs
    }

    private func updateFocusForTabChanges(ids: [UUID]) {
        lastVisibleTabIDs = visibleTabIDs
        guard let focusedTabId else { return }
        if !ids.contains(focusedTabId) {
            self.focusedTabId = ids.first
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "square.grid.2x2")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("No tabs open")
                .font(TypographyTokens.prominent.weight(.semibold))
            Text("Create a new tab to see it appear here.")
                .font(TypographyTokens.callout)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
