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
    @State private var availableWidth: CGFloat = .infinity

    var body: some View {
        let split = TabPageOverflow.split(pages: pages, selected: selected, available: availableWidth,
                                          width: TabPageChipsMetrics.chipWidth, moreWidth: TabPageChipsMetrics.moreWidth)
        HStack(spacing: SpacingTokens.xxs2) {
            Rectangle()
                .fill(ColorTokens.Separator.primary)
                .frame(width: LayoutTokens.TabPages.dividerWidth, height: LayoutTokens.TabPages.dividerHeight)
                .padding(.horizontal, LayoutTokens.TabPages.dividerPadding)
                .accessibilityHidden(true)
            HStack(spacing: LayoutTokens.TabPages.spacing) {
                ForEach(split.shown, id: \.self) { page in
                    chip(page)
                }
                if !split.more.isEmpty {
                    moreMenu(split.more)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .frame(height: LayoutTokens.TabPages.chipHeight)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    /// Round 36.2, OF1: the pages that don't fit, at the end.
    private func moreMenu(_ rest: [String]) -> some View {
        Menu {
            ForEach(rest, id: \.self) { page in
                Button(page) { withAnimation(motion.press) { onSelect(page) } }
            }
        } label: {
            HStack(spacing: SpacingTokens.xxxs) {
                Text("More")
                Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold))
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, LayoutTokens.TabPages.chipHorizontalPadding)
            .frame(height: LayoutTokens.TabPages.chipHeight)
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More pages")
        .accessibilityLabel("More pages")
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

/// Which pages show in the tab and which go into More (round 36.2, OF1): as many as fit in order,
/// with room for More; the shown page always stays visible, taking the last slot if it would
/// otherwise be hidden.
enum TabPageOverflow {
    static func split(pages: [String], selected: String?, available: CGFloat,
                      width: (String) -> CGFloat, moreWidth: CGFloat) -> (shown: [String], more: [String]) {
        let total = pages.reduce(CGFloat.zero) { $0 + width($1) }
        guard total > available, !pages.isEmpty else { return (pages, []) }
        var shown: [String] = []
        var used = moreWidth
        for page in pages {
            let next = width(page)
            guard used + next <= available else { break }
            shown.append(page)
            used += next
        }
        if let selected, pages.contains(selected), !shown.contains(selected) {
            // Take pages off the end until the selected one fits in their place.
            while let last = shown.last, used + width(selected) > available {
                used -= width(last)
                shown.removeLast()
            }
            shown.append(selected)
        }
        if shown.isEmpty, let first = selected ?? pages.first { shown = [first] }
        return (shown, pages.filter { !shown.contains($0) })
    }
}

/// The width of a tool tab showing its pages: exactly its title, hairline and pages (RW1).
enum TabPageChipsMetrics {
    @MainActor
    static func idealWidth(title: String, pages: [String]) -> CGFloat {
        let titleFont = NSFont.systemFont(ofSize: TypographyTokens.AppKit.detail.pointSize, weight: .medium)
        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let pagesWidth = pages.reduce(CGFloat.zero) { $0 + chipWidth($1) }
        return ceil(titleWidth + pagesWidth + LayoutTokens.TabPages.tabChrome)
    }

    /// One page with its padding and spacing, measured semibold so switching pages never changes
    /// the tab's width.
    @MainActor
    static func chipWidth(_ page: String) -> CGFloat {
        let pageFont = NSFont.systemFont(ofSize: TypographyTokens.AppKit.detail.pointSize, weight: .semibold)
        return ceil((page as NSString).size(withAttributes: [.font: pageFont]).width)
            + LayoutTokens.TabPages.chipHorizontalPadding * 2 + LayoutTokens.TabPages.spacing
    }

    /// More and its chevron.
    @MainActor
    static var moreWidth: CGFloat { chipWidth("More") + SpacingTokens.sm }
}
