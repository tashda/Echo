import SwiftUI
import AppKit

extension EnvironmentValues {
    /// False inside a tab that is kept mounted but not shown (`KeptAliveTabsView`), so views such
    /// as the SQL editor can hand keyboard focus over when their tab comes back.
    @Entry var isActiveWorkspaceTab = true
}

/// Keeps the most recently used tabs mounted and shows only the active one, so switching back
/// is instant and keeps scroll, undo and the cursor (Design/05-components.md › Tabs, round 9
/// TFIX). Hidden tabs are out of hit testing and accessibility, and keyboard focus is cleared on
/// every switch so typing never lands in a tab you can't see.
struct KeptAliveTabsView<Content: View>: View {
    let tabs: [WorkspaceTab]
    let activeTab: WorkspaceTab
    @ViewBuilder let content: (WorkspaceTab) -> Content

    /// How many tabs stay mounted, the active one included. Each costs an editor and a grid.
    static var keptTabCount: Int { 3 }

    @State private var recentTabIDs: [UUID] = []

    var body: some View {
        ZStack {
            ForEach(keptTabs, id: \.id) { tab in
                let isActive = tab.id == activeTab.id
                content(tab)
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                    .accessibilityHidden(!isActive)
                    .zIndex(isActive ? 1 : 0)
                    .environment(\.isActiveWorkspaceTab, isActive)
            }
        }
        .onAppear { remember(activeTab.id) }
        .onChange(of: activeTab.id) { _, newID in
            NSApp.keyWindow?.makeFirstResponder(nil)
            remember(newID)
        }
    }

    private var keptTabs: [WorkspaceTab] {
        var ids = recentTabIDs
        if !ids.contains(activeTab.id) { ids.insert(activeTab.id, at: 0) }
        return ids.compactMap { id in tabs.first { $0.id == id } }
    }

    private func remember(_ tabID: UUID) {
        recentTabIDs = Self.recentTabIDs(recentTabIDs, activating: tabID, openIDs: Set(tabs.map(\.id)))
    }

    /// The tabs to keep mounted after `tabID` becomes active: it goes first, closed tabs drop
    /// out, and the list is cut to `keptTabCount`.
    static func recentTabIDs(_ recent: [UUID], activating tabID: UUID, openIDs: Set<UUID>) -> [UUID] {
        var ids = recent.filter { $0 != tabID && openIDs.contains($0) }
        ids.insert(tabID, at: 0)
        return Array(ids.prefix(keptTabCount))
    }
}
