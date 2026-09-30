import SwiftUI

/// The single-line tab bar in one of the three styles, with the tool's pages shown the way the
/// page style asks (inside the tab, as a group, or as a menu). ST1 and TT6 draw below the bar.
struct LabRound14TabBar: View {
    nonisolated static let coordinateSpace = "round14-bar"

    let style: LabRound14BarStyle
    let pageStyle: LabRound14PageStyle
    @Bindable var state: LabRound14TabState
    let animation: Animation
    let onToolTabFrame: (CGRect) -> Void

    @Namespace private var tabSpace

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                if tab.hasPages && pageStyle == .group {
                    groupedTool(tab)
                } else {
                    tabButton(tab, index: index)
                }
            }
            addButton
        }
        .padding(LayoutTokens.DesignLabRound14.plateInset / 2)
        .frame(height: LayoutTokens.DesignLabRound14.plateHeight)
        .background(LabRound14Track(style: style))
        .frame(height: LayoutTokens.DesignLabRound14.barHeight)
        .coordinateSpace(.named(Self.coordinateSpace))
    }

    // MARK: Tabs

    @ViewBuilder
    private func tabButton(_ tab: LabRound14Tab, index: Int) -> some View {
        let isActive = state.activeID == tab.id
        let unfolds = tab.hasPages && pageStyle == .unfold && isActive
        LabRound14TabButton(
            style: style, tab: tab, isActive: isActive, title: title(for: tab),
            showsDivider: showsDivider(at: index), namespace: tabSpace,
            onSelect: { withAnimation(animation) { state.activeID = tab.id } },
            onClose: { withAnimation(animation) { state.close(tab) } }
        ) {
            if unfolds {
                LabRound14PageChips(style: style, pages: tab.pages, selected: state.page(of: tab), compact: true, animation: animation) { page in
                    withAnimation(animation) { state.select(page: page, of: tab) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
            }
            if tab.hasPages && pageStyle == .menu {
                pageMenu(tab)
            }
        }
        .fixedSize(horizontal: unfolds, vertical: false)
        .frame(maxWidth: unfolds ? nil : .infinity)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpace)) } action: { frame in
            if tab.hasPages { onToolTabFrame(frame) }
        }
    }

    private func title(for tab: LabRound14Tab) -> Text? {
        guard tab.hasPages, pageStyle == .menu else { return nil }
        return Text("\(Text(tab.title)) \(Text("› \(state.page(of: tab))").foregroundStyle(ColorTokens.Text.secondary))")
    }

    private func pageMenu(_ tab: LabRound14Tab) -> some View {
        Menu {
            ForEach(Array(tab.pages.enumerated()), id: \.element) { index, page in
                Button(page) { withAnimation(animation) { state.select(page: page, of: tab) } }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(TypographyTokens.compact.weight(.bold))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Pages")
    }

    /// Hairlines only between two inactive tabs, in the styles that use them.
    private func showsDivider(at index: Int) -> Bool {
        guard style != .today, index > 0 else { return false }
        let tab = state.tabs[index], previous = state.tabs[index - 1]
        return tab.id != state.activeID && previous.id != state.activeID
    }

    // MARK: ST3 group

    @ViewBuilder
    private func groupedTool(_ tab: LabRound14Tab) -> some View {
        Button {
            withAnimation(animation) {
                state.isGroupOpen.toggle()
                if state.isGroupOpen { state.activeID = tab.id }
                else if state.activeID == tab.id, let other = state.tabs.first(where: { !$0.hasPages }) { state.activeID = other.id }
            }
        } label: {
            Text(tab.title)
                .font(TypographyTokens.detail.weight(.bold))
                .foregroundStyle(ColorTokens.DesignLabRound14.groupLabelTitle)
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.DesignLabRound14.tabHeight - SpacingTokens.xxs)
                .background(ColorTokens.Explorer.jobs, in: .rect(cornerRadius: LayoutTokens.DesignLabRound14.groupChipCornerRadius))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(state.isGroupOpen ? "Collapse group" : "Expand group")
        if state.isGroupOpen {
            ForEach(tab.pages, id: \.self) { page in
                let pageTab = LabRound14Tab(id: "\(tab.id).\(page)", title: page, database: tab.database, symbol: tab.symbol)
                LabRound14TabButton(
                    style: style, tab: pageTab, isActive: state.activeID == tab.id && state.page(of: tab) == page,
                    namespace: tabSpace,
                    onSelect: { withAnimation(animation) { state.select(page: page, of: tab) } },
                    onClose: {}
                )
                .overlay(alignment: .bottom) {
                    Capsule().fill(ColorTokens.Explorer.jobs)
                        .frame(height: SpacingTokens.xxxs)
                        .padding(.horizontal, SpacingTokens.xs)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
            }
        }
    }

    private var addButton: some View {
        Button { withAnimation(animation) { state.addQuery() } } label: {
            Image(systemName: "plus")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.DesignLabRound14.addButtonWidth, height: LayoutTokens.DesignLabRound14.tabHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New Query Tab")
        .accessibilityLabel("New Query Tab")
    }
}
