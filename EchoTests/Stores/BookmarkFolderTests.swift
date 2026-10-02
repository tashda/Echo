import Foundation
import Testing
@testable import Echo

@Suite("Bookmark folders and order")
struct BookmarkFolderTests {
    private let repository = BookmarkRepository()
    private let server = UUID()

    private func project() -> Project {
        var project = Project(name: "Test")
        project.bookmarkFolders = ["AML", "Employees"]
        project.bookmarks = [
            Bookmark(connectionID: server, databaseName: "db", title: "A", query: "select 1", source: .tab, folder: "AML"),
            Bookmark(connectionID: server, databaseName: "db", title: "B", query: "update t set x = 1", source: .tab, folder: "AML"),
            Bookmark(connectionID: server, databaseName: "db", title: "C", query: "exec p", source: .tab, folder: "Employees"),
        ]
        return project
    }

    @Test func oldProjectsDecodeWithoutFolders() throws {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Project(name: "Old"))) as? [String: Any])
        json.removeValue(forKey: "bookmarkFolders")
        let decoded = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.bookmarkFolders.isEmpty)
    }

    @Test func namesMustBeFreeAndRenamesMoveBookmarks() {
        var project = project()
        #expect(!repository.addFolder("AML", to: &project))
        #expect(!repository.addFolder("No Folder", to: &project))
        #expect(repository.addFolder("Reports", to: &project))
        #expect(repository.uniqueFolderName(in: project) == "New Folder")
        #expect(repository.renameFolder("AML", to: "Checkpoints", in: &project))
        #expect(project.bookmarks.filter { $0.folder == "Checkpoints" }.count == 2)
        #expect(!repository.renameFolder("Checkpoints", to: "Employees", in: &project))
    }

    @Test func foldersReorder() {
        var project = project()
        repository.moveFolder("Employees", before: "AML", in: &project)
        #expect(project.bookmarkFolders == ["Employees", "AML"])
        repository.moveFolder("Employees", by: 1, in: &project)
        #expect(project.bookmarkFolders == ["AML", "Employees"])
    }

    @Test func deletingAFolderKeepsOrDeletesItsBookmarks() {
        var keep = project()
        repository.deleteFolder("AML", .keepBookmarks(movedTo: "Employees"), in: &keep)
        #expect(keep.bookmarkFolders == ["Employees"])
        #expect(keep.bookmarks.filter { $0.folder == "Employees" }.count == 3)

        var toNoFolder = project()
        repository.deleteFolder("AML", .keepBookmarks(movedTo: nil), in: &toNoFolder)
        #expect(toNoFolder.bookmarks.filter { $0.folder == nil }.count == 2)

        var delete = project()
        repository.deleteFolder("AML", .deleteBookmarks, in: &delete)
        #expect(delete.bookmarks.count == 1)
    }

    @Test func yourOrderHoldsAndSortOnceRearranges() {
        var project = project()
        let a = project.bookmarks[0].id, b = project.bookmarks[1].id
        repository.moveBookmark(b, toFolder: "AML", before: a, in: &project)
        #expect(repository.bookmarks(inFolder: "AML", of: project).map(\.id) == [b, a])
        repository.sortOnce(by: .name, in: &project)
        #expect(repository.bookmarks(inFolder: "AML", of: project).map(\.title) == ["A", "B"])
        repository.moveBookmark(a, by: 1, in: &project)
        #expect(repository.bookmarks(inFolder: "AML", of: project).map(\.title) == ["B", "A"])
    }

    @Test func statementKindsReadTheFirstKeyword() {
        #expect(Bookmark(connectionID: server, databaseName: nil, title: nil, query: "  select 1", source: .tab).statementKind == .read)
        #expect(Bookmark(connectionID: server, databaseName: nil, title: nil, query: "UPDATE t SET x = 1", source: .tab).statementKind == .change)
        #expect(Bookmark(connectionID: server, databaseName: nil, title: nil, query: "exec sp_who", source: .tab).statementKind == .procedure)
    }
}
