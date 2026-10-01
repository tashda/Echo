import Foundation

/// A tool tab whose sections are pages in its tab (ST2, round 36.2): the tab shows the titles and
/// switches the page; the tool draws the page that is selected.
@MainActor
protocol ToolPageSource: AnyObject {
    /// The pages this tool has on this server, in order.
    var pageTitles: [String] { get }
    /// The page shown, or nil before the tool has one.
    var currentPageTitle: String? { get }
    func selectPage(titled title: String)
}

/// A tool whose pages are the cases of an enum it already switches on.
@MainActor
protocol ToolPaged: ToolPageSource {
    associatedtype Page: RawRepresentable<String> & CaseIterable & Hashable
    var selectedPage: Page { get set }
    /// The pages this server has; every case unless the tool narrows it (Server Properties on
    /// PostgreSQL has four of six).
    var availablePages: [Page] { get }
}

extension ToolPaged {
    var availablePages: [Page] { Array(Page.allCases) }
    var pageTitles: [String] { availablePages.map(\.rawValue) }
    var currentPageTitle: String? { selectedPage.rawValue }

    func selectPage(titled title: String) {
        guard let page = Page(rawValue: title), availablePages.contains(page) else { return }
        selectedPage = page
    }
}
