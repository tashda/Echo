import AppKit
import SwiftUI

/// A tool's pages in its active tab (ST2, refined in round 36.1): a short hairline after the
/// title, then the pages at the title's size on the tab itself, the shown one semibold on a soft
/// pill. Scrolls sideways when a tool has more pages than fit.
struct TabPageChips: View {
    let pages: [String]
    let selected: String?
    let onSelect: (String) -> Void

    @Namespace private var chipSpace
    @Environment(\.echoMotion) private var motion

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Rectangle()
                .fill(ColorTokens.Separator.primary)
                .frame(width: LayoutTokens.TabPages.dividerWidth, height: LayoutTokens.TabPages.dividerHeight)
                .padding(.horizontal, LayoutTokens.TabPages.dividerPadding)
                .accessibilityHidden(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LayoutTokens.TabPages.spacing) {
                    ForEach(pages, id: \.self) { page in
                        chip(page)
                    }
                }
            }
            .frame(height: LayoutTokens.TabPages.chipHeight)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    private func chip(_ page: String) -> some View {
        let isSelected = page == selected
        return Button { withAnimation(motion.press) { onSelect(page) } } label: {
            Text(page)
                .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, LayoutTokens.TabPages.chipHorizontalPadding)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The width of a tool tab showing its pages: exactly its title, hairline and pages (RW1).
enum TabPageChipsMetrics {
    @MainActor
    static func idealWidth(title: String, pages: [String]) -> CGFloat {
        let size = TypographyTokens.AppKit.detail.pointSize
        let titleFont = NSFont.systemFont(ofSize: size, weight: .medium)
        // Every page measured semibold, so switching pages never changes the tab's width.
        let pageFont = NSFont.systemFont(ofSize: size, weight: .semibold)
        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let pagesWidth = pages.reduce(CGFloat.zero) { total, page in
            total + (page as NSString).size(withAttributes: [.font: pageFont]).width
                + LayoutTokens.TabPages.chipHorizontalPadding * 2 + LayoutTokens.TabPages.spacing
        }
        return ceil(titleWidth + pagesWidth + LayoutTokens.TabPages.tabChrome)
    }
}
