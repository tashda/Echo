import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    /// A bookmark or a bookmark folder dragged inside the Bookmarks page (declared in Info.plist).
    static let echoBookmarkItem = UTType(exportedAs: "dev.echodb.echo.bookmark-item")
}

/// What a drag in the Bookmarks page carries (round IC): a bookmark (moved between folders, or
/// dropped into an editor as its SQL) or a folder (reordered).
struct BookmarkDragItem: Codable, Sendable, Transferable {
    enum Kind: String, Codable, Sendable {
        case bookmark
        case folder
    }

    let kind: Kind
    let bookmarkID: UUID?
    let folder: String?
    /// Dropped anywhere that takes text, such as the query editor, a bookmark is its SQL (BO1).
    let sql: String

    static func bookmark(_ bookmark: Bookmark) -> BookmarkDragItem {
        BookmarkDragItem(kind: .bookmark, bookmarkID: bookmark.id, folder: bookmark.folder, sql: bookmark.query)
    }

    static func folder(_ name: String) -> BookmarkDragItem {
        BookmarkDragItem(kind: .folder, bookmarkID: nil, folder: name, sql: "")
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .echoBookmarkItem)
        ProxyRepresentation(exporting: \.sql)
    }
}
