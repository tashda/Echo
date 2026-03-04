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

    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(TabStore.self) internal var tabStore
    
    @EnvironmentObject internal var appModel: AppModel
    @Environment(\.colorScheme) internal var colorScheme

    @State internal var animateIn = false
    @State internal var collapsedServers: Set<UUID> = []
    @State internal var collapsedDatabases: Set<String> = []
    @State internal var focusedTabId: UUID?
    @State internal var lastVisibleTabIDs: [UUID] = []
    @State internal var draggingTabId: UUID?
    @State internal var dropTargetTabId: UUID?

    private let comfortableMinCardWidth: CGFloat = 260
    private let comfortableMaxCardWidth: CGFloat = 360
    private let comfortableGridSpacing: CGFloat = 18
    private let compactMinCardWidth: CGFloat = 170
    private let compactMaxCardWidth: CGFloat = 240
    private let compactGridSpacing: CGFloat = 12

    internal var orderedTabIDs: [UUID] { tabs.map(\.id) }
    internal var visibleTabIDs: [UUID] {
        groupedTabs.reduce(into: [UUID]()) { result, serverGroup in
            let serverID = serverGroup.connection.id
            guard !collapsedServers.contains(serverID) else { return }
            for databaseGroup in serverGroup.databaseGroups.values {
                let identifier = databaseIdentifier(for: databaseGroup.databaseName, serverID: serverID)
                guard !collapsedDatabases.contains(identifier) else { continue }
                for section in databaseGroup.sections {
                    result.append(contentsOf: section.tabs.map(\.id))
                }
            }
        }
    }

    internal func databaseBackground(isActive: Bool) -> LinearGradient {
        let base = Color.white.opacity(colorScheme == .dark ? 0.04 : 0.7)
        let accent = heroAccentColor.opacity(isActive ? (colorScheme == .dark ? 0.28 : 0.14) : (colorScheme == .dark ? 0.16 : 0.08))
        return LinearGradient(
            colors: [
                base,
                accent
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    internal func tabCard(for tab: WorkspaceTab, serverID: UUID, databaseIdentifier: String) -> some View {
        Group {
            switch overviewStyle {
            case .comfortable:
                TabPreviewCard(
                    tab: tab,
                    isActive: tab.id == activeTabId,
                    isFocused: tab.id == focusedTabId,
                    isDropTarget: tab.id == dropTargetTabId,
                    onSelect: { onSelectTab(tab.id) },
                    onClose: { onCloseTab(tab.id) }
                )
            case .compact:
                CompactTabPreviewCard(
                    tab: tab,
                    isActive: tab.id == activeTabId,
                    isDropTarget: tab.id == dropTargetTabId,
                    onSelect: { onSelectTab(tab.id) },
                    onClose: { onCloseTab(tab.id) }
                )
            }
        }
        .onTapGesture { focusedTabId = tab.id }
        .focusEffectDisabled(true)
        .contextMenu {
            tabContextMenu(for: tab, serverID: serverID, databaseIdentifier: databaseIdentifier)
        }
        .onDrag {
            draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        } preview: { EmptyView() }
#if os(macOS)
        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
            targetTabID: tab.id,
            isTrailingPlaceholder: false,
            tabStore: tabStore,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId
        ))
#endif
    }

    internal var animation: Animation { .spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2) }

    internal var overviewStyle: TabOverviewStyle {
        projectStore.globalSettings.tabOverviewStyle
    }

    internal var gridConfiguration: (columns: [GridItem], spacing: CGFloat) {
        switch overviewStyle {
        case .comfortable:
            return (
                [GridItem(.adaptive(minimum: comfortableMinCardWidth, maximum: comfortableMaxCardWidth), spacing: comfortableGridSpacing, alignment: .top)],
                comfortableGridSpacing
            )
        case .compact:
            return (
                [GridItem(.adaptive(minimum: compactMinCardWidth, maximum: compactMaxCardWidth), spacing: compactGridSpacing, alignment: .top)],
                compactGridSpacing
            )
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            overviewHero

            if !groupedTabs.isEmpty {
                overviewControls
                    .transition(.opacity)
            }

            ScrollView {
                if groupedTabs.isEmpty {
                    emptyState
                        .padding(.top, 120)
                        .padding(.horizontal, 32)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedTabs) { serverGroup in
                            serverGroupView(serverGroup)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
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
        .padding(.bottom, 40)
        .background(overviewBackground)
        .onAppear {
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
                updateFocusForTabChanges(ids: ids)
            }
        }
        .onChange(of: focusedTabId) { _, _ in
            DispatchQueue.main.async {
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

    internal var groupedTabs: [ServerGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.connection.id }

        return grouped.keys.compactMap { id in
            guard let connection = connectionStore.connections.first(where: { $0.id == id }) else { return nil }
            let serverTabs = grouped[id] ?? []
            return ServerGroup(
                connection: connection,
                databaseGroups: databaseGroups(for: serverTabs),
                totalTabCount: serverTabs.count
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("No tabs open")
                .font(.title3.weight(.semibold))
            Text("Create a new tab to see it appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func databaseGroups(for tabs: [WorkspaceTab]) -> [String: DatabaseGroup] {
        let grouped = Dictionary(grouping: tabs) { databaseKey(for: $0) }
        return grouped.mapValues { databaseTabs in
            DatabaseGroup(
                databaseName: databaseKey(for: databaseTabs[0]),
                sections: sectionGroups(for: databaseTabs)
            )
        }
    }

    private func sectionGroups(for tabs: [WorkspaceTab]) -> [SectionGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.kind }
        return WorkspaceTab.Kind.allCases.compactMap { kind in
            guard let kindTabs = grouped[kind], !kindTabs.isEmpty else { return nil }
            return SectionGroup(kind: kind, tabs: kindTabs)
        }
    }

    internal func databaseKey(for tab: WorkspaceTab) -> String {
        tab.connection.database.isEmpty ? "default" : tab.connection.database
    }

    internal var activeConnectionID: UUID? {
        appModel.sessionManager.activeConnectionID
    }

    internal var activeDatabaseName: String? {
        appModel.sessionManager.activeDatabaseName
    }

    internal var heroAccentColor: Color {
#if os(macOS)
        Color(nsColor: NSColor.controlAccentColor)
#else
        Color.accentColor
#endif
    }
}

#if os(macOS)
internal struct TabOverviewDropDelegate: DropDelegate {
    let targetTabID: UUID?
    let isTrailingPlaceholder: Bool
    let tabStore: TabStore
    @Binding var draggingTabId: UUID?
    @Binding var dropTargetTabId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggingTabId != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTabId else { return }
        Task { @MainActor in
            if isTrailingPlaceholder {
                let count = tabStore.tabs.count
                guard count > 0 else { return }
                let destinationIndex = count - 1
                tabStore.moveTab(id: draggingID, to: destinationIndex)
                dropTargetTabId = nil
            } else if let targetID = targetTabID,
                      targetID != draggingID,
                      let targetIndex = tabStore.index(of: targetID) {
                tabStore.moveTab(id: draggingID, to: targetIndex)
                dropTargetTabId = targetID
            }
        }
    }

    func dropExited(info: DropInfo) {
        if isTrailingPlaceholder {
            dropTargetTabId = nil
        } else if dropTargetTabId == targetTabID {
            dropTargetTabId = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabId = nil
        dropTargetTabId = nil
        return true
    }
}
#endif
