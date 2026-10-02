import SwiftUI

/// Works out how wide each tab is and which pages show, for one way of fitting the pages (FP0 to FP3).
/// FP0 follows Echo's TabUnfoldLayout and TabPageOverflow; the others are the proposals.
struct LabTBarPlanner {
    let tabs: [LabTBarTab]
    let fit: LabTBarFit
    let stripWidth: CGFloat
    let icons: LabTBarIcons

    private var others: CGFloat { CGFloat(max(tabs.count - 1, 1)) }
    private var hasIcon: Bool { icons != .none }

    /// What a tab needs to show its title and every page.
    func needs(_ tab: LabTBarTab) -> CGFloat {
        LabTBarMetrics.needed(tab, compact: fit.usesCompactPages, icon: hasIcon)
    }

    /// The width the tab takes when it is the front tool tab.
    func unfolded(_ tab: LabTBarTab) -> CGFloat {
        switch fit {
        case .more: min(needs(tab), stripWidth * LabTBarMetrics.maxShare)
        case .grow, .compact: min(needs(tab), stripWidth - others * LabTBarMetrics.iconOnlyWidth)
        case .row, .adaptive: stripWidth / CGFloat(tabs.count)
        }
    }

    /// The room the pages have: inside the tab, or the whole row.
    func pageRoom(_ tab: LabTBarTab) -> CGFloat {
        fit == .row ? stripWidth - SpacingTokens.lg
            : unfolded(tab) - LabTBarMetrics.titleWidth(tab.title) - LabTBarMetrics.chrome(icon: hasIcon)
    }

    /// The pages shown and the ones left in More: as many as fit, in order, the selected one always shown.
    func split(_ tab: LabTBarTab, selected: String?) -> (shown: [String], more: [String]) {
        let compact = fit.usesCompactPages
        let width: (String) -> CGFloat = { LabTBarMetrics.chipWidth($0, compact: compact) }
        let available = pageRoom(tab)
        let pages = tab.pages
        guard LabTBarMetrics.pagesWidth(pages, compact: compact) > available, !pages.isEmpty else { return (pages, []) }
        var shown: [String] = []
        var used = LabTBarMetrics.moreWidth
        for page in pages {
            guard used + width(page) <= available else { break }
            shown.append(page)
            used += width(page)
        }
        if let selected, pages.contains(selected), !shown.contains(selected) {
            while let last = shown.last, used + width(selected) > available {
                used -= width(last)
                shown.removeLast()
            }
            shown.append(selected)
        }
        if shown.isEmpty, let first = selected ?? pages.first { shown = [first] }
        return (shown, pages.filter { !shown.contains($0) })
    }

    /// Every tab's width while `activeID` is in front.
    func widths(active activeID: String) -> [CGFloat] {
        let equal = stripWidth / CGFloat(tabs.count)
        guard let tool = tabs.first(where: { $0.id == activeID }), !tool.pages.isEmpty, tabs.count > 1 else {
            return tabs.map { _ in equal }
        }
        let front = unfolded(tool)
        let rest = max((stripWidth - front) / others, 0)
        return tabs.map { $0.id == activeID ? front : rest }
    }

    /// Tabs too narrow for a title show only their icon (FP1 and FP3).
    func isIconOnly(_ width: CGFloat, isActive: Bool) -> Bool {
        guard hasIcon, !isActive, fit == .grow || fit == .compact else { return false }
        return width < LabTBarMetrics.smallestTitledWidth
    }
}
