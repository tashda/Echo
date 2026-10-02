import SwiftUI

/// One tab of the strip, its icon, its dot and its pages.
extension LabTBarStrip {
    func symbol(_ tab: LabTBarTab) -> String { icons == .today ? tab.kind.today : tab.kind.proposed }

    func showsIcon(_ tab: LabTBarTab, isActive: Bool) -> Bool {
        switch icons {
        case .today, .literal, .family: true
        case .active: isActive
        case .none: false
        }
    }

    func iconColor(_ tab: LabTBarTab, isActive: Bool) -> Color {
        let base = icons == .family ? tab.kind.family.tint : (isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        return base.opacity(isActive ? 0.9 : 0.75)
    }

    func selectedPage(_ tab: LabTBarTab) -> String? { pageByTab[tab.id] ?? tab.pages.first }

    /// The width of the icon, title and dot together, before the tab pads them.
    private func naturalWidth(_ tab: LabTBarTab, isActive: Bool) -> CGFloat {
        var width = LabTBarMetrics.titleWidth(tab.title)
        if showsIcon(tab, isActive: isActive) { width += SpacingTokens.sm2 + SpacingTokens.xxs2 }
        if showsDots { width += SpacingTokens.xxs2 * 2 }
        return width
    }

    @ViewBuilder
    func tabView(_ tab: LabTBarTab, width: CGFloat) -> some View {
        let isActive = tab.id == activeID
        let hasPages = !tab.pages.isEmpty && fit != .row
        let iconOnly = planner.isIconOnly(width, isActive: isActive)
        Group {
            if isToday {
                todayContent(tab, isActive: isActive, hasPages: hasPages, iconOnly: iconOnly)
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(width: width, height: Self.tabHeight)
                    .background { if isActive { plate } }
            } else if motionStyle == .layer {
                Color.clear.frame(width: width, height: Self.tabHeight)
                    .background { if !usesSlidingPlate { plate.opacity(isActive ? 1 : 0) } }
            } else {
                labelCell(tab, width: width)
                    .clipShape(Capsule())
                    .background { if !usesSlidingPlate { plate.opacity(isActive ? 1 : 0) } }
            }
        }
        .contentShape(Capsule())
        .onTapGesture { select(tab.id) }
    }

    /// A tab's icon, title and pages at the width the tab will have, placed as the motion asks.
    func labelCell(_ tab: LabTBarTab, width: CGFloat) -> some View {
        let isActive = tab.id == activeID
        let hasPages = !tab.pages.isEmpty && fit != .row
        let iconOnly = planner.isIconOnly(width, isActive: isActive)
        let centred = max(14, (width - naturalWidth(tab, isActive: isActive)) / 2)
        let inset: CGFloat = switch motionStyle {
        case .anchored: isActive ? SpacingTokens.sm : 14
        case .frozen, .layer, .steady, .stillIcons: 14
        default: isActive && hasPages ? SpacingTokens.sm : centred
        }
        // MO5 and MO7 put the words in place at once; MO6 animates nothing about them at all.
        let snaps = motionStyle == .printed || motionStyle == .frozen
        return calmContent(tab, isActive: isActive, hasPages: hasPages, iconOnly: iconOnly)
            .fixedSize()
            .padding(.leading, motionStyle == .layer ? (isActive && hasPages ? SpacingTokens.sm : centred) : inset)
            .transaction { if snaps { $0.animation = nil } }
            .frame(width: width, height: Self.tabHeight, alignment: .leading)
    }

    private var plate: some View {
        Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection)
    }

    /// Echo today: the title shrinks with the tab, and the pages come and go as the tab becomes active.
    private func todayContent(_ tab: LabTBarTab, isActive: Bool, hasPages: Bool, iconOnly: Bool) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            iconView(tab, isActive: isActive)
            if !iconOnly {
                Text(tab.title)
                    .font(isActive && hasPages ? TypographyTokens.detail.weight(.medium) : TypographyTokens.detail)
                    .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
                dotView(tab)
            }
            if isActive, hasPages {
                pagesView(tab, isActive: true)
                    .transition(.asymmetric(insertion: .opacity.animation(motion.press.delay(motion.settleDuration * 0.4)),
                                            removal: .opacity.animation(motion.press)))
            }
        }
    }

    /// The calmer tab: nothing re-flows; what does not fit is clipped, and the pages fade with the tab.
    private func calmContent(_ tab: LabTBarTab, isActive: Bool, hasPages: Bool, iconOnly: Bool) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            if motionStyle == .stillIcons {
                if showsIcon(tab, isActive: isActive) { Color.clear.frame(width: SpacingTokens.sm2, height: 1) }
            } else {
                iconView(tab, isActive: isActive)
            }
            Group {
                Text(tab.title)
                    .font(isActive && hasPages ? TypographyTokens.detail.weight(.medium) : TypographyTokens.detail)
                    .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .lineLimit(1)
                dotView(tab)
            }
            .opacity(iconOnly ? 0 : 1)
            .animation(motionStyle == .frozen ? nil : pagesCurve, value: iconOnly)
            if hasPages {
                pagesView(tab, isActive: isActive)
                    .opacity(isActive ? 1 : 0)
                    .animation(pagesCurve, value: isActive)
            }
        }
    }

    @ViewBuilder
    func iconView(_ tab: LabTBarTab, isActive: Bool) -> some View {
        if showsIcon(tab, isActive: isActive) {
            Image(systemName: symbol(tab))
                .font(TypographyTokens.detail)
                .foregroundStyle(iconColor(tab, isActive: isActive))
                .frame(width: SpacingTokens.sm2)
        }
    }

    @ViewBuilder
    private func dotView(_ tab: LabTBarTab) -> some View {
        if showsDots {
            Circle().fill(tab.serverColor).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
        }
    }

    /// The hairline and the pages inside the tab (FP0 to FP3).
    func pagesView(_ tab: LabTBarTab, isActive: Bool) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Rectangle().fill(ColorTokens.Separator.primary)
                .frame(width: LayoutTokens.TabPages.dividerWidth, height: LayoutTokens.TabPages.dividerHeight)
                .padding(.horizontal, LayoutTokens.TabPages.dividerPadding)
            chips(tab)
        }
    }

    /// The pages as chips, with More after them when some do not fit (FP0).
    func chips(_ tab: LabTBarTab) -> some View {
        let split = planner.split(tab, selected: selectedPage(tab))
        let compact = fit.usesCompactPages
        return HStack(spacing: LabTBarMetrics.chipSpacing) {
            ForEach(split.shown, id: \.self) { page in
                let isSelected = page == selectedPage(tab)
                Button { withAnimation(motion.press) { pageByTab[tab.id] = page } } label: {
                    Text(LabTBarMetrics.label(page, compact: compact))
                        .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, compact ? LabTBarMetrics.compactChipPadding : LabTBarMetrics.chipPadding)
                        .frame(height: LayoutTokens.TabPages.chipHeight)
                        .background {
                            if isSelected {
                                Capsule().fill(ColorTokens.TabStrip.Pages.selected)
                                    .matchedGeometryEffect(id: "page-\(tab.id)", in: pageSpace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if !split.more.isEmpty {
                Menu {
                    ForEach(split.more, id: \.self) { page in Button(page) { pageByTab[tab.id] = page } }
                } label: {
                    HStack(spacing: SpacingTokens.xxxs) {
                        Text("More")
                        Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold))
                    }
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, LabTBarMetrics.chipPadding)
                    .frame(height: LayoutTokens.TabPages.chipHeight)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            }
        }
    }

    /// FP2: the pages on a line of their own under the strip.
    func pageRow(_ tab: LabTBarTab) -> some View {
        chips(tab)
            .padding(.leading, SpacingTokens.sm)
            .frame(width: stripWidth, height: LayoutTokens.TabPages.chipHeight + SpacingTokens.xs, alignment: .leading)
            .background(ColorTokens.Sidebar.hoverFill.opacity(0.6), in: Capsule())
            .transition(.opacity.combined(with: .offset(y: -4)))
    }

    var capacity: CGFloat {
        switch fit {
        case .more: stripWidth * LabTBarMetrics.maxShare
        case .grow, .compact: stripWidth - CGFloat(tabs.count - 1) * LabTBarMetrics.iconOnlyWidth
        case .row, .adaptive: stripWidth
        }
    }

    /// What the strip says about the pages of the front tab: whether they all fit, and what they need.
    var fitCaption: String {
        guard let tab = activeTab, !tab.pages.isEmpty else { return "This tab has no pages. Click the tool tab to see them." }
        let split = planner.split(tab, selected: selectedPage(tab))
        let needs = fit == .row ? LabTBarMetrics.pagesWidth(tab.pages, compact: false) : planner.needs(tab)
        let room = Int(capacity)
        if split.more.isEmpty { return "All \(tab.pages.count) pages show. It needs \(Int(needs)) pt of \(room) pt." }
        return "\(split.more.count) of \(tab.pages.count) pages are in More. It needs \(Int(needs)) pt but gets \(room) pt."
    }

    var fitCaptionColor: Color {
        guard let tab = activeTab, !tab.pages.isEmpty else { return ColorTokens.Text.tertiary }
        return planner.split(tab, selected: selectedPage(tab)).more.isEmpty ? ColorTokens.Text.secondary : ColorTokens.Status.warning
    }
}
