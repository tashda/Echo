import Foundation

/// Bookmark folders and order (round IC, IC-I one level, IC-J your order). Pure edits of a project;
/// the caller saves it. No Folder is not a folder: a bookmark with `folder == nil` is in it, and it
/// always comes last.
extension BookmarkRepository {
    static let noFolderTitle = "No Folder"

    /// The project's bookmarks in a folder (nil is No Folder), in your order: by `sortIndex`, then
    /// those without one, newest first.
    func bookmarks(inFolder folder: String?, of project: Project) -> [Bookmark] {
        Self.ordered(project.bookmarks.filter { $0.folder == folder })
    }

    static func ordered(_ bookmarks: [Bookmark]) -> [Bookmark] {
        bookmarks.sorted { lhs, rhs in
            switch (lhs.sortIndex, rhs.sortIndex) {
            case let (l?, r?): return l == r ? lhs.createdAt > rhs.createdAt : l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.createdAt > rhs.createdAt
            }
        }
    }

    /// A free name: "New Folder", then "New Folder 2", …
    func uniqueFolderName(_ base: String = "New Folder", in project: Project) -> String {
        var name = base
        var number = 2
        while project.bookmarkFolders.contains(name) || name == Self.noFolderTitle {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }

    /// Adds a folder at the end. Returns false for an empty or taken name.
    @discardableResult
    func addFolder(_ name: String, to project: inout Project) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFree(name, in: project) else { return false }
        project.bookmarkFolders.append(name)
        return true
    }

    /// Renames a folder and moves its bookmarks with it. Returns false for an empty or taken name.
    @discardableResult
    func renameFolder(_ old: String, to new: String, in project: inout Project) -> Bool {
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = project.bookmarkFolders.firstIndex(of: old) else { return false }
        if new == old { return true }
        guard isFree(new, in: project) else { return false }
        project.bookmarkFolders[index] = new
        for i in project.bookmarks.indices where project.bookmarks[i].folder == old {
            project.bookmarks[i].folder = new
        }
        return true
    }

    func isFree(_ name: String, in project: Project) -> Bool {
        !name.isEmpty && name != Self.noFolderTitle && !project.bookmarkFolders.contains(name)
    }

    /// Moves a folder to sit before another (nil: to the end).
    func moveFolder(_ name: String, before target: String?, in project: inout Project) {
        guard name != target, let from = project.bookmarkFolders.firstIndex(of: name) else { return }
        project.bookmarkFolders.remove(at: from)
        let to = target.flatMap { project.bookmarkFolders.firstIndex(of: $0) } ?? project.bookmarkFolders.endIndex
        project.bookmarkFolders.insert(name, at: to)
    }

    /// Moves a folder one place up or down (⌥⌘↑ ⌥⌘↓).
    func moveFolder(_ name: String, by step: Int, in project: inout Project) {
        guard let from = project.bookmarkFolders.firstIndex(of: name) else { return }
        let to = from + step
        guard project.bookmarkFolders.indices.contains(to) else { return }
        project.bookmarkFolders.swapAt(from, to)
    }

    /// Sort Folders by Name, once.
    func sortFoldersByName(in project: inout Project) {
        project.bookmarkFolders.sort { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// What deleting a folder does with the bookmarks in it.
    enum FolderDeletion: Equatable {
        /// Keep them, moved to this folder (nil: No Folder).
        case keepBookmarks(movedTo: String?)
        /// Delete them with the folder.
        case deleteBookmarks
    }

    func deleteFolder(_ name: String, _ deletion: FolderDeletion, in project: inout Project) {
        project.bookmarkFolders.removeAll { $0 == name }
        switch deletion {
        case .keepBookmarks(let destination):
            let target = destination.flatMap { project.bookmarkFolders.contains($0) ? $0 : nil }
            let base = (project.bookmarks.filter { $0.folder == target }.compactMap(\.sortIndex).max() ?? 0) + 1
            var offset = 0.0
            for bookmark in bookmarks(inFolder: name, of: project) {
                guard let i = project.bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { continue }
                project.bookmarks[i].folder = target
                project.bookmarks[i].sortIndex = base + offset
                offset += 1
            }
        case .deleteBookmarks:
            project.bookmarks.removeAll { $0.folder == name }
        }
    }

    /// Moves a bookmark into a folder (nil: No Folder), before another bookmark there, or to the
    /// end. Everything in the target folder gets an explicit place, so your order holds.
    func moveBookmark(_ id: UUID, toFolder folder: String?, before targetID: UUID? = nil, in project: inout Project) {
        guard project.bookmarks.contains(where: { $0.id == id }) else { return }
        var order = bookmarks(inFolder: folder, of: project).map(\.id).filter { $0 != id }
        let at = targetID.flatMap { order.firstIndex(of: $0) } ?? order.endIndex
        order.insert(id, at: at)
        for (place, bookmarkID) in order.enumerated() {
            guard let i = project.bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { continue }
            project.bookmarks[i].folder = folder
            project.bookmarks[i].sortIndex = Double(place)
        }
    }

    /// Moves a bookmark one place up or down within its folder.
    func moveBookmark(_ id: UUID, by step: Int, in project: inout Project) {
        guard let bookmark = project.bookmarks.first(where: { $0.id == id }) else { return }
        let order = bookmarks(inFolder: bookmark.folder, of: project).map(\.id)
        guard let from = order.firstIndex(of: id) else { return }
        let to = from + step
        guard order.indices.contains(to) else { return }
        let before: UUID? = step < 0 ? order[to] : (order.indices.contains(to + 1) ? order[to + 1] : nil)
        moveBookmark(id, toFolder: bookmark.folder, before: before, in: &project)
    }

    enum SortKey { case name, lastUsed, dateAdded }

    /// Sort Once By (IC-J): rearranges every folder once; the order is yours again after.
    func sortOnce(by key: SortKey, in project: inout Project) {
        let folders: [String?] = project.bookmarkFolders.map { Optional($0) } + [nil]
        for folder in folders {
            let sorted = project.bookmarks.filter { $0.folder == folder }.sorted { lhs, rhs in
                switch key {
                case .name:
                    return lhs.primaryLine.localizedStandardCompare(rhs.primaryLine) == .orderedAscending
                case .lastUsed:
                    return (lhs.lastOpenedAt ?? lhs.updatedAt ?? lhs.createdAt) > (rhs.lastOpenedAt ?? rhs.updatedAt ?? rhs.createdAt)
                case .dateAdded:
                    return lhs.createdAt > rhs.createdAt
                }
            }
            for (place, bookmark) in sorted.enumerated() {
                guard let i = project.bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { continue }
                project.bookmarks[i].sortIndex = Double(place)
            }
        }
    }

    /// A new bookmark goes to the top of its folder.
    func topSortIndex(inFolder folder: String?, of project: Project) -> Double {
        (project.bookmarks.filter { $0.folder == folder }.compactMap(\.sortIndex).min() ?? 1) - 1
    }
}
