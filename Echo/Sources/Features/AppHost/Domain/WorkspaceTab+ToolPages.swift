import Foundation

/// A tool tab's pages, shown unfolded in its tab (ST2). Only Activity Monitor has pages so far.
extension WorkspaceTab {
    var toolPages: [String] { activityMonitor?.pageTitles ?? [] }

    var currentToolPage: String? { activityMonitor?.currentPage }

    func selectToolPage(_ page: String) {
        activityMonitor?.selectedSection = page
    }
}
