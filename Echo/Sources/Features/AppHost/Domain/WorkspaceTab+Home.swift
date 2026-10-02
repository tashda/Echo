import Foundation

/// A query tab's home (round IC, H1): nothing yet, a bookmark, or a .sql file. The tab strip marks
/// it in the icon's place, and the tab's menu shows it in Bookmarks or Finder, or lets it go.
extension WorkspaceTab {
    var hasHome: Bool { bookmarkContext != nil || fileURL != nil }

    /// A query tab with no home yet shows a ☆ in the icon's place while the pointer is on it.
    var offersSaveStar: Bool { query != nil && !isPinned && !hasHome }

    /// What the strip's icon layer draws for this tab. A dot replaces the glyph while there are
    /// changes not saved yet; a tab under the pointer with no home leaves the room to its ☆.
    func homeMark(isHovered: Bool) -> TabIconLayer.Mark {
        guard let query else { return .kind }
        if isHovered && offersSaveStar { return .hidden }
        if query.isEdited { return .edited }
        if bookmarkContext != nil { return .bookmark }
        if fileURL != nil { return .file }
        return .kind
    }

    /// The tooltip's line for the home, if there is one.
    var homeTooltip: String? {
        if let context = bookmarkContext {
            return "Bookmark: \(context.displayName). \u{2318}S saves to it."
        }
        if let url = fileURL {
            return (url.path as NSString).abbreviatingWithTildeInPath
        }
        return nil
    }

    /// Detach from Bookmark or File: the tab keeps its SQL and has no home; the next Save asks.
    func detachFromHome() {
        bookmarkContext = nil
        fileURL = nil
    }
}
