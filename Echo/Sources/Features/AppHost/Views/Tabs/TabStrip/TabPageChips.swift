import SwiftUI

/// ST2 (design board, 2026-09-30): a tool's pages inside its active tab. The selected page
/// uses the strip's raised fill; the rest are plain titles. Scrolls sideways when a tool has
/// more pages than fit.
struct TabPageChips: View {
    let pages: [String]
    let selected: String?
    let onSelect: (String) -> Void

    @Namespace private var chipSpace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LayoutTokens.TabPages.spacing) {
                ForEach(pages, id: \.self) { page in
                    chip(page)
                }
            }
            .padding(.horizontal, LayoutTokens.TabPages.spacing)
        }
        .scrollClipDisabled(false)
        .frame(height: LayoutTokens.TabPages.chipHeight)
        .background(ColorTokens.TabStrip.Pages.track, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    private func chip(_ page: String) -> some View {
        let isSelected = page == selected
        return Button { withAnimation(.snappy(duration: 0.22)) { onSelect(page) } } label: {
            Text(page)
                .font(TypographyTokens.label.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, LayoutTokens.TabPages.chipHorizontalPadding)
                .frame(height: LayoutTokens.TabPages.chipHeight - LayoutTokens.TabPages.spacing * 2)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(ColorTokens.TabStrip.Pages.selected)
                            .shadow(color: ColorTokens.TabStrip.Pages.selectedShadow, radius: 0.5, y: 0.5)
                            .matchedGeometryEffect(id: "page", in: chipSpace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The ideal width of a tool tab once it shows its pages, so the strip can make room.
enum TabPageChipsMetrics {
    @MainActor
    static func idealWidth(title: String, pages: [String]) -> CGFloat {
        let titleWidth = (title as NSString).size(withAttributes: [.font: TypographyTokens.AppKit.detail]).width
        let pagesWidth = pages.reduce(CGFloat.zero) { total, page in
            total + (page as NSString).size(withAttributes: [.font: TypographyTokens.AppKit.label]).width
                + LayoutTokens.TabPages.chipHorizontalPadding * 2 + LayoutTokens.TabPages.spacing
        }
        return ceil(titleWidth + pagesWidth + LayoutTokens.TabPages.tabChrome)
    }
}
