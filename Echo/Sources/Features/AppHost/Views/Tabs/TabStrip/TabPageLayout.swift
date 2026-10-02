import AppKit
import SwiftUI

/// The names of a tool's pages as the tab shows them (round 49, FP3): a few long ones are
/// shortened so that every page fits in the tab. The row under the strip uses the full names.
enum TabPageNames {
    static let short: [String: String] = [
        "Event Triggers": "Triggers", "Composite Types": "Composite", "Range Types": "Ranges", "Text Search": "Search",
        "Foreign Data": "Foreign", "Prepared Txns": "Prepared", "Configuration": "Config", "Replication": "Repl",
        "Password Policies": "Passwords", "Advanced Objects": "Advanced", "Data Masking": "Masking", "Tablespaces": "Spaces",
        "Certificates": "Certs",
    ]

    static func label(_ page: String, compact: Bool) -> String {
        compact ? (short[page] ?? page) : page
    }
}

/// The widths of a tool tab's parts, measured at the 11pt the tab draws them in.
enum TabPageChipsMetrics {
    @MainActor
    static func titleWidth(_ title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: TypographyTokens.AppKit.detail.pointSize, weight: .medium)
        return ceil((title as NSString).size(withAttributes: [.font: font]).width)
    }

    /// One page with its padding and spacing, measured semibold so switching pages never changes
    /// the tab's width.
    @MainActor
    static func chipWidth(_ page: String, compact: Bool) -> CGFloat {
        let font = NSFont.systemFont(ofSize: TypographyTokens.AppKit.detail.pointSize, weight: .semibold)
        let padding = compact ? LayoutTokens.TabPages.compactChipHorizontalPadding : LayoutTokens.TabPages.chipHorizontalPadding
        return ceil((TabPageNames.label(page, compact: compact) as NSString).size(withAttributes: [.font: font]).width)
            + padding * 2 + LayoutTokens.TabPages.spacing
    }

    @MainActor
    static func pagesWidth(_ pages: [String], compact: Bool) -> CGFloat {
        pages.reduce(CGFloat.zero) { $0 + chipWidth($1, compact: compact) }
    }

    /// The width a tab needs to show its title and every page in the tab (FP3): the title, the
    /// hairline, the pages and the tab's own chrome.
    @MainActor
    static func idealWidth(title: String, pages: [String]) -> CGFloat {
        ceil(titleWidth(title) + pagesWidth(pages, compact: true) + LayoutTokens.TabPages.tabChrome)
    }
}

/// Where a tool's pages go: in the tab, or on a row of their own when not even the shortened
/// pages fit the strip (round 49, FP4). Nothing is ever hidden.
enum TabPagePlacement {
    case inTab, row

    /// The tab can take the strip less `iconOnlyWidth` for every other tab.
    static func resolve(idealWidth: CGFloat, tabCount: Int, totalWidth: CGFloat) -> TabPagePlacement {
        idealWidth <= TabUnfoldLayout.room(tabCount: tabCount, totalWidth: totalWidth) ? .inTab : .row
    }
}

/// The widths of the tabs when one tool tab unfolds its pages; empty when every tab keeps the
/// equal width.
enum TabUnfoldLayout {
    /// The most the front tool tab can take: the strip, less a icon-only tab for each other tab.
    static func room(tabCount: Int, totalWidth: CGFloat) -> CGFloat {
        totalWidth - CGFloat(max(tabCount - 1, 0)) * LayoutTokens.TabPages.iconOnlyWidth
    }

    static func widths(tabIDs: [UUID], unfoldedID: UUID, idealUnfoldedWidth: CGFloat,
                       equalWidth: CGFloat, totalWidth: CGFloat) -> [UUID: CGFloat] {
        guard tabIDs.contains(unfoldedID) else { return [:] }
        guard tabIDs.count > 1 else {
            // Alone: its own width, unless that is the whole strip anyway.
            return idealUnfoldedWidth < totalWidth ? [unfoldedID: idealUnfoldedWidth] : [:]
        }
        let unfolded = min(idealUnfoldedWidth, room(tabCount: tabIDs.count, totalWidth: totalWidth))
        guard unfolded != equalWidth else { return [:] }
        let others = max((totalWidth - unfolded) / CGFloat(tabIDs.count - 1), 0)
        return Dictionary(uniqueKeysWithValues: tabIDs.map { ($0, $0 == unfoldedID ? unfolded : others) })
    }

    /// A tab squeezed below this shows only its icon.
    static func isIconOnly(width: CGFloat, isFront: Bool) -> Bool {
        !isFront && width < LayoutTokens.TabPages.smallestTitledWidth
    }
}
