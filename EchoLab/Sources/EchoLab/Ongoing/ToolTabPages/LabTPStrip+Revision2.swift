import SwiftUI

/// Revision 2 of round 36.1: three ways to keep the pages in the tab bar without a shape inside
/// the tab (TP5 group, TP6 beside, TP7 hanging). A tool with more pages than fit ends with a
/// More menu (36.2, OF1).
extension LabTPStrip {
    /// Five pages show; the rest go in More. A page chosen from More takes the last slot.
    func visiblePages(_ tab: LabTPTab) -> (shown: [String], more: [String]) {
        let limit = 5
        guard tab.pages.count > limit + 1 else { return (tab.pages, []) }
        var shown = Array(tab.pages.prefix(limit))
        let current = selected(tab)
        if !shown.contains(current) { shown[limit - 1] = current }
        return (shown, tab.pages.filter { !shown.contains($0) })
    }

    /// A tab as every other tab draws it: icon and title, the raised plate when active.
    func plainTab(_ tab: LabTPTab) -> some View {
        Label(tab.title, systemImage: tab.symbol)
            .font(TypographyTokens.detail)
            .foregroundStyle(tab.id == activeID ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
            .background {
                if tab.id == activeID { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) }
            }
    }

    /// TP5: a tinted label with the tool's name, then each page drawn as a tab of the strip.
    func groupView(_ tab: LabTPTab) -> some View {
        let pages = visiblePages(tab)
        return HStack(spacing: SpacingTokens.none) {
            Label(tab.title, systemImage: tab.symbol)
                .font(TypographyTokens.label.weight(.semibold))
                .foregroundStyle(tab.tint)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: SpacingTokens.md2)
                .background(tab.tint.opacity(0.14), in: Capsule())
                .padding(.horizontal, SpacingTokens.xxs)
            ForEach(pages.shown, id: \.self) { name in pageTab(tab, name) }
            if !pages.more.isEmpty { moreMenu(tab, pages.more) }
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(tab.tint.opacity(0.5)).frame(height: SpacingTokens.xxxs).padding(.horizontal, SpacingTokens.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pageTab(_ tab: LabTPTab, _ name: String) -> some View {
        let on = name == selected(tab)
        return Text(name)
            .font(TypographyTokens.detail.weight(on ? .medium : .regular))
            .foregroundStyle(on ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, SpacingTokens.sm)
            .frame(minWidth: SpacingTokens.xxxl)
            .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
            .background { if on { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
    }

    /// TP6: the pages follow the tab on the strip's track as words; the shown one in the accent colour.
    func besidePages(_ tab: LabTPTab) -> some View {
        let pages = visiblePages(tab)
        return HStack(spacing: SpacingTokens.sm) {
            ForEach(pages.shown, id: \.self) { name in
                let on = name == selected(tab)
                Text(name)
                    .font(TypographyTokens.detail.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? ColorTokens.accent : ColorTokens.Text.secondary)
                    .lineLimit(1).fixedSize()
                    .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
            }
            if !pages.more.isEmpty { moreMenu(tab, pages.more) }
        }
    }

    /// TP7: a slim row joined to the bottom of the active tab, holding its pages.
    func hangingRow(_ tab: LabTPTab) -> some View {
        let pages = visiblePages(tab)
        return HStack(spacing: SpacingTokens.xxxs) {
            ForEach(pages.shown, id: \.self) { name in
                let on = name == selected(tab)
                Text(name)
                    .font(TypographyTokens.label.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, SpacingTokens.xs)
                    .frame(height: SpacingTokens.md2)
                    .background { if on { Capsule().fill(ColorTokens.Sidebar.selectedFill) } }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
            }
            if !pages.more.isEmpty { moreMenu(tab, pages.more) }
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .frame(height: SpacingTokens.lg)
        .background(ColorTokens.Workspace.card, in: UnevenRoundedRectangle(bottomLeadingRadius: SpacingTokens.sm, bottomTrailingRadius: SpacingTokens.sm, style: .continuous))
        .shadow(ShadowTokens.railSelection)
        .padding(.leading, hangX + SpacingTokens.xxxs)
    }

    private func moreMenu(_ tab: LabTPTab, _ rest: [String]) -> some View {
        Menu {
            ForEach(rest, id: \.self) { name in
                Button(name) { withAnimation(motion.press) { page[tab.id] = name } }
            }
        } label: {
            Text("More").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
        .menuStyle(.button).buttonStyle(.plain).fixedSize()
        .padding(.horizontal, SpacingTokens.xs)
    }
}
