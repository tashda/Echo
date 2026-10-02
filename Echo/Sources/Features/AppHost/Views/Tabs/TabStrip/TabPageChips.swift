import SwiftUI

/// A tool's pages (ST2, refined in round 36.1 and round 49): every page, at the title's size, the
/// shown one semibold on a soft pill. In the tab they follow a short hairline and use the
/// shortened names (FP3); on the row under the strip (FP2) they use the full names.
struct TabPageChips: View {
    let pages: [String]
    let selected: String?
    /// In the tab: shortened names, tighter pages and a hairline before them.
    var isInTab = true
    let onSelect: (String) -> Void

    @Namespace private var chipSpace
    @Environment(\.echoMotion) private var motion

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            if isInTab {
                Rectangle()
                    .fill(ColorTokens.Separator.primary)
                    .frame(width: LayoutTokens.TabPages.dividerWidth, height: LayoutTokens.TabPages.dividerHeight)
                    .padding(.horizontal, LayoutTokens.TabPages.dividerPadding)
                    .accessibilityHidden(true)
            }
            HStack(spacing: LayoutTokens.TabPages.spacing) {
                ForEach(pages, id: \.self) { page in
                    chip(page)
                }
            }
            .frame(height: LayoutTokens.TabPages.chipHeight)
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    private func chip(_ page: String) -> some View {
        let isSelected = page == selected
        let padding = isInTab ? LayoutTokens.TabPages.compactChipHorizontalPadding : LayoutTokens.TabPages.chipHorizontalPadding
        return Button { withAnimation(motion.press) { onSelect(page) } } label: {
            Text(TabPageNames.label(page, compact: isInTab))
                .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, padding)
                .frame(height: LayoutTokens.TabPages.chipHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(ColorTokens.TabStrip.Pages.selected)
                            .matchedGeometryEffect(id: "page", in: chipSpace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(page)
        .accessibilityLabel(page)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The pages on a row of their own under the strip, for the tool in front, when not even the
/// shortened pages fit the strip (round 49, FP2 inside FP4).
struct TabPageRow: View {
    let pages: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        TabPageChips(pages: pages, selected: selected, isInTab: false, onSelect: onSelect)
            .padding(.leading, SpacingTokens.sm)
            .frame(maxWidth: .infinity, minHeight: LayoutTokens.TabPages.rowHeight, alignment: .leading)
            .background(ColorTokens.Sidebar.hoverFill.opacity(0.6), in: Capsule())
    }
}
