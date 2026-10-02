import Foundation

/// The inspector column's pages (round IC): Details, Bookmarks, History and Notifications share
/// the trailing column, switched by the page strip, ⌥⌘1 to ⌥⌘4 and View › Inspector.
enum InspectorPage: String, CaseIterable, Identifiable, Sendable {
    case details
    case bookmarks
    case history
    case notifications

    var id: String { rawValue }

    static let defaultsKey = "workspace.inspectorPage"

    var title: String {
        switch self {
        case .details: "Details"
        case .bookmarks: "Bookmarks"
        case .history: "History"
        case .notifications: "Notifications"
        }
    }

    var systemImage: String {
        switch self {
        case .details: "info.circle"
        case .bookmarks: "bookmark"
        case .history: "clock"
        case .notifications: "bell"
        }
    }

    /// ⌥⌘ and this digit shows the page, or closes the column if it shows.
    var shortcutDigit: Character {
        switch self {
        case .details: "1"
        case .bookmarks: "2"
        case .history: "3"
        case .notifications: "4"
        }
    }
}

extension AppState {
    /// Whether the trailing column is out, on any page.
    var isInspectorColumnVisible: Bool { isInspectorVisible }

    /// The column shows Notifications.
    var isNotificationHistoryVisible: Bool { isInspectorVisible && inspectorPage == .notifications }

    /// The column shows Details. Setting it is a deliberate request: true shows Details (switching
    /// from any other page), false closes the column only while it shows Details.
    var showInfoSidebar: Bool {
        get { isInspectorVisible && inspectorPage == .details }
        set {
            if newValue {
                showInspectorPage(.details)
            } else if inspectorPage == .details {
                isInspectorVisible = false
            }
        }
    }

    /// Opens the column on a page.
    func showInspectorPage(_ page: InspectorPage) {
        inspectorPage = page
        isInspectorVisible = true
        if page == .details { hasUnseenDetails = false }
    }

    /// The page strip, ⌥⌘1–4, View › Inspector and the bell: asking for the page that shows closes
    /// the column; any other request shows that page.
    func toggleInspectorPage(_ page: InspectorPage) {
        if isInspectorVisible && inspectorPage == page {
            isInspectorVisible = false
        } else {
            showInspectorPage(page)
        }
    }

    /// The Inspector button and ⌥⌘I: show the column on the page it was last on, or close it.
    func toggleInspector() {
        if isInspectorVisible {
            isInspectorVisible = false
        } else {
            showInspectorPage(inspectorPage)
        }
    }

    /// The bell.
    func toggleNotificationHistory() { toggleInspectorPage(.notifications) }

    /// A tab's Show in Bookmarks: the Bookmarks page, on that bookmark.
    func revealBookmark(_ id: UUID) {
        revealedBookmarkID = id
        showInspectorPage(.bookmarks)
    }

    /// A toast's Show All.
    func showNotificationHistory() { showInspectorPage(.notifications) }

    /// Details changed because something was selected (round IC, F1): a closed column opens on
    /// Details when `autoOpen` (Settings › Results › open the inspector on selection); on Details
    /// it simply updates; on another page the page stays and the strip marks Details. Returns
    /// whether this opened the column, so the caller can close it again when the selection goes.
    @discardableResult
    func noteDetailsChanged(autoOpen: Bool) -> Bool {
        guard isInspectorVisible else {
            guard autoOpen else { return false }
            showInspectorPage(.details)
            return true
        }
        if inspectorPage != .details { hasUnseenDetails = true }
        return false
    }
}
