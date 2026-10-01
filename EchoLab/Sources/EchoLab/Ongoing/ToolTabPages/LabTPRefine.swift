import SwiftUI

/// Revision 3 of round 36.1: TP0 refined. The owner keeps TP0's idea (the title, then the pages
/// on a grey track inside the active tab) and wants it perfect. Each knob fixes one thing that
/// looks off in Echo today.
struct LabTPRefine: Equatable {
    var width: LabTPWidth = .hug
    var track: LabTPTrack = .docked
    var text: LabTPText = .matched
    var divider: LabTPDivider = .none
    var chip: LabTPChip = .raised

    static let recommended = LabTPRefine()

    @MainActor static func from(_ values: RoundValues) -> LabTPRefine {
        LabTPRefine(width: .init(rawValue: values["width"]) ?? .hug, track: .init(rawValue: values["track"]) ?? .docked,
                    text: .init(rawValue: values["text"]) ?? .matched, divider: .init(rawValue: values["divider"]) ?? .none,
                    chip: .init(rawValue: values["chip"]) ?? .raised)
    }
}

/// How wide the active tab is.
enum LabTPWidth: String, CaseIterable {
    case fill = "RW0 · It stretches to 62% of the strip and centres its content (today)"
    case hug = "RW1 · Exactly as wide as its title and pages; the other tabs share the rest"
}

/// Where the grey track sits in the tab.
enum LabTPTrack: String, CaseIterable {
    case floating = "RT0 · A grey pill floating inside the tab with its own margins (today)"
    case docked = "RT1 · Docked to the tab's right end, 2pt in, its curve following the tab's"
    case none = "RT2 · No track: the pages sit on the tab itself"
}

/// How the title and the pages are set.
enum LabTPText: String, CaseIterable {
    case today = "RX0 · Title at 11pt, pages at 10pt (today)"
    case matched = "RX1 · Title and pages at 11pt on one baseline; the title medium, the shown page semibold"
}

/// What separates the title from the pages.
enum LabTPDivider: String, CaseIterable {
    case none = "RD0 · Only space (today)"
    case hairline = "RD1 · A short hairline"
}

/// The shown page.
enum LabTPChip: String, CaseIterable {
    case raised = "RC0 · A white raised pill (today)"
    case tint = "RC1 · A pill tinted with the tool's colour"
}

extension LabTPStrip {
    /// TP0 refined: the active tool tab with its title and pages.
    func refinedTab(_ tab: LabTPTab, _ refine: LabTPRefine) -> some View {
        let inset = SpacingTokens.xxxs
        let plateHeight = SpacingTokens.lg + SpacingTokens.xxxs
        let docked = refine.track == .docked
        return HStack(spacing: SpacingTokens.xs) {
            Label(tab.title, systemImage: tab.symbol)
                .font(refine.text == .matched ? TypographyTokens.detail.weight(.medium) : TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1).fixedSize()
            if refine.divider == .hairline {
                Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.sm)
            }
            refinedPages(tab, refine, height: docked ? plateHeight - inset * 2 : LayoutTokens.TabPages.chipHeight)
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, docked ? inset : SpacingTokens.sm)
        .frame(height: plateHeight)
        .frame(maxWidth: refine.width == .fill ? .infinity : nil)
        .background { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) }
        .fixedSize(horizontal: refine.width == .hug, vertical: false)
    }

    private func refinedPages(_ tab: LabTPTab, _ refine: LabTPRefine, height: CGFloat) -> some View {
        let pages = visiblePages(tab)
        let pad = refine.track == .none ? SpacingTokens.none : LayoutTokens.TabPages.spacing
        return HStack(spacing: LayoutTokens.TabPages.spacing) {
            ForEach(pages.shown, id: \.self) { name in refinedChip(tab, name, refine, height: height - pad * 2) }
            if !pages.more.isEmpty {
                Menu {
                    ForEach(pages.more, id: \.self) { name in
                        Button(name) { withAnimation(motion.press) { page[tab.id] = name } }
                    }
                } label: {
                    Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .menuStyle(.button).buttonStyle(.plain).fixedSize()
                .padding(.horizontal, SpacingTokens.xxs2)
                .help("More pages")
            }
        }
        .padding(.horizontal, pad)
        .frame(height: height)
        .background { if refine.track != .none { Capsule().fill(ColorTokens.TabStrip.Pages.track) } }
    }

    private func refinedChip(_ tab: LabTPTab, _ name: String, _ refine: LabTPRefine, height: CGFloat) -> some View {
        let on = name == selected(tab)
        let font = refine.text == .matched ? TypographyTokens.detail : TypographyTokens.label
        return Text(name)
            .font(font.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? (refine.chip == .tint ? tab.tint : ColorTokens.Text.primary) : ColorTokens.Text.secondary)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, refine.text == .matched ? SpacingTokens.xs2 : LayoutTokens.TabPages.chipHorizontalPadding)
            .frame(height: height)
            .background {
                if on {
                    switch refine.chip {
                    case .raised:
                        if refine.track == .none {
                            Capsule().fill(ColorTokens.TabStrip.Pages.track)
                        } else {
                            Capsule().fill(ColorTokens.TabStrip.Pages.selected)
                                .shadow(color: ColorTokens.TabStrip.Pages.selectedShadow, radius: 0.5, y: 0.5)
                        }
                    case .tint:
                        Capsule().fill(tab.tint.opacity(0.16))
                    }
                }
            }
            .contentShape(Capsule())
            .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
    }
}
