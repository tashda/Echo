import Foundation

protocol BookmarkRepositoryProtocol: Sendable {
    func bookmarks(for connectionID: UUID, in project: Project) -> [Bookmark]
    func addBookmark(_ bookmark: Bookmark, to project: inout Project)
    func removeBookmark(_ bookmarkID: UUID, from project: inout Project)
    func updateBookmark(_ bookmarkID: UUID, in project: inout Project, update: (inout Bookmark) -> Void)
}

final class BookmarkRepository: BookmarkRepositoryProtocol, @unchecked Sendable {
    func bookmarks(for connectionID: UUID, in project: Project) -> [Bookmark] {
        sort(project.bookmarks.filter { $0.connectionID == connectionID })
    }
    
    func addBookmark(_ bookmark: Bookmark, to project: inout Project) {
        if let existingIndex = project.bookmarks.firstIndex(where: {
            $0.connectionID == bookmark.connectionID &&
            $0.databaseName?.caseInsensitiveCompare(bookmark.databaseName ?? "") == .orderedSame &&
            $0.query == bookmark.query
        }) {
            project.bookmarks.remove(at: existingIndex)
        }
        project.bookmarks.insert(bookmark, at: 0)
    }
    
    func removeBookmark(_ bookmarkID: UUID, from project: inout Project) {
        project.bookmarks.removeAll { $0.id == bookmarkID }
    }
    
    func updateBookmark(_ bookmarkID: UUID, in project: inout Project, update: (inout Bookmark) -> Void) {
        guard let index = project.bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
        update(&project.bookmarks[index])
    }
    
    private func sort(_ bookmarks: [Bookmark]) -> [Bookmark] {
        bookmarks.sorted { $0.updatedAt > $1.updatedAt }
    }
}
