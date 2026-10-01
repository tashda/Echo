import SwiftUI

/// The palette's tab overview (round 35.1, TO6): every tab in this window under its server, with
/// its state. Hover moves the selection; a click goes to the tab.
struct TabOverviewPaletteList: View {
    @Bindable var model: TabOverviewPaletteModel
    let onOpen: (UUID) -> Void

    @Environment(TabStore.self) private var tabStore
    @State private var pointerTracker = PointerMoveTracker()

    var body: some View {
        let entries = TabOverviewEntry.entries(for: tabStore.tabs)
        let groups = TabOverviewEntry.groups(TabOverviewEntry.matching(model.query, in: entries))
        let selected = model.selection(in: groups.flatMap(\.entries), activeID: tabStore.activeTabId)
        if groups.isEmpty {
            Text(tabStore.tabs.isEmpty ? "No open tabs" : "No tabs match")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.FloatingSurface.rowHeight, alignment: .leading)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(groups) { group in
                            header(group)
                            ForEach(group.entries) { entry in
                                row(entry, isSelected: entry.id == selected)
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: LayoutTokens.CommandPalette.listMaxHeight)
                .onChange(of: model.selectedID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func header(_ group: TabOverviewServerGroup) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(group.server)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("\(group.entries.count)")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.CommandPalette.sectionHeaderHeight, alignment: .bottomLeading)
    }

    @ViewBuilder
    private func row(_ entry: TabOverviewEntry, isSelected: Bool) -> some View {
        if let tab = tabStore.tabs.first(where: { $0.id == entry.id }) {
            Button {
                onOpen(entry.id)
            } label: {
                TabOverviewPaletteRow(tab: tab, entry: entry, isSelected: isSelected, isActive: entry.id == tabStore.activeTabId)
            }
            .buttonStyle(.plain)
            .id(entry.id)
            // Only a real mouse move selects: rows scrolling under a still pointer (after an arrow
            // key) mustn't take the selection back.
            .onContinuousHover { phase in
                if case .active = phase, pointerTracker.pointerMoved() { model.selectedID = entry.id }
            }
        }
    }
}
