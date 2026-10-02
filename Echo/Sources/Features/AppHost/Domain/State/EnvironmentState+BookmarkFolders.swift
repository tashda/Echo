import Foundation

/// Edits to the inspector's bookmarks and folders (round IC). Each edit saves the project at once
/// and is undoable with ⌘Z when the caller passes the window's undo manager.
extension EnvironmentState {
    /// The project the Bookmarks page shows: the selected one, as currently stored.
    var bookmarkProject: Project? {
        guard let selected = projectStore.selectedProject else { return nil }
        return projectStore.projects.first { $0.id == selected.id } ?? selected
    }

    /// Changes the selected project's bookmarks or folders, saves it, and registers an undo.
    func editBookmarks(_ actionName: String, undoManager: UndoManager? = nil, _ change: (inout Project) -> Void) {
        guard var project = bookmarkProject else { return }
        let before = project
        change(&project)
        guard project != before else { return }
        storeBookmarks(of: project)
        registerBookmarkUndo(restoring: before, actionName: actionName, undoManager: undoManager)
    }

    /// Changes the project that holds a bookmark (any project), saves it, and registers an undo.
    func editBookmark(_ id: UUID, actionName: String, undoManager: UndoManager? = nil, _ change: (inout Bookmark) -> Void) {
        guard var project = projectStore.projects.first(where: { $0.bookmarks.contains { $0.id == id } }) else { return }
        let before = project
        bookmarkRepository.updateBookmark(id, in: &project, update: change)
        guard project != before else { return }
        storeBookmarks(of: project)
        registerBookmarkUndo(restoring: before, actionName: actionName, undoManager: undoManager)
    }

    /// Updates the store at once, so a quick second edit sees the first, then writes to disk.
    private func storeBookmarks(of project: Project) {
        if let index = projectStore.projects.firstIndex(where: { $0.id == project.id }) {
            projectStore.projects[index] = project
            if projectStore.selectedProject?.id == project.id { projectStore.selectedProject = project }
        }
        Task { await projectStore.saveProject(project) }
    }

    private func registerBookmarkUndo(restoring snapshot: Project, actionName: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        let box = BookmarkUndoBox(snapshot: snapshot, actionName: actionName, undoManager: undoManager)
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.restoreBookmarks(box) }
        }
        undoManager.setActionName(actionName)
    }

    /// Puts back a project's bookmarks and folders, registering the redo.
    private func restoreBookmarks(_ box: BookmarkUndoBox) {
        guard var project = projectStore.projects.first(where: { $0.id == box.snapshot.id }) else { return }
        let current = project
        project.bookmarks = box.snapshot.bookmarks
        project.bookmarkFolders = box.snapshot.bookmarkFolders
        storeBookmarks(of: project)
        registerBookmarkUndo(restoring: current, actionName: box.actionName, undoManager: box.undoManager)
    }

    /// Adds a bookmark at the top of its folder (round IC).
    func addBookmark(for connection: SavedConnection, databaseName: String?, title: String?, query: String,
                     source: Bookmark.Source, folder: String?, note: String?) async -> Bookmark? {
        guard var project = projectStore.projects.first(where: { $0.id == (connection.projectID ?? projectStore.selectedProject?.id) }) else {
            return nil
        }
        let folder = folder.flatMap { project.bookmarkFolders.contains($0) ? $0 : nil }
        let bookmark = Bookmark(connectionID: connection.id, databaseName: databaseName, title: title, query: query, source: source,
                                folder: folder, note: note?.isEmpty == true ? nil : note,
                                sortIndex: bookmarkRepository.topSortIndex(inFolder: folder, of: project))
        bookmarkRepository.addBookmark(bookmark, to: &project)
        storeBookmarks(of: project)
        return bookmark
    }

    /// Opens a bookmark in a new tab, not run (HP0); the tab's home is the bookmark, so ⌘S saves
    /// back into it (round IC). Connect and Open when its server isn't connected.
    func openBookmark(_ bookmark: Bookmark) {
        openSavedQuery(sql: bookmark.query, connectionID: bookmark.connectionID, database: bookmark.databaseName) { tab in
            tab.bookmarkContext = WorkspaceTab.BookmarkTabContext(bookmark: bookmark)
            if let title = bookmark.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                tab.title = title
            }
            tab.query?.markSaved()
        }
        editBookmark(bookmark.id, actionName: "Open Bookmark") { $0.lastOpenedAt = Date() }
    }
}

/// What an undo of a bookmark edit needs. Only touched on the main actor.
private final class BookmarkUndoBox: @unchecked Sendable {
    let snapshot: Project
    let actionName: String
    weak var undoManager: UndoManager?

    init(snapshot: Project, actionName: String, undoManager: UndoManager) {
        self.snapshot = snapshot
        self.actionName = actionName
        self.undoManager = undoManager
    }
}
