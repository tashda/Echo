import XCTest
@testable import Echo

final class BookmarkRepositoryTests: XCTestCase {
    private var repo: BookmarkRepository!
    private var project: Project!
    private let connectionID = UUID()

    override func setUp() {
        super.setUp()
        repo = BookmarkRepository()
        project = TestFixtures.project()
    }

    // MARK: - Add

    func testAddBookmarkInsertsAtIndex0() {
        let b1 = TestFixtures.bookmark(connectionID: connectionID, query: "SELECT 1")
        let b2 = TestFixtures.bookmark(connectionID: connectionID, query: "SELECT 2")

        repo.addBookmark(b1, to: &project)
        repo.addBookmark(b2, to: &project)

        XCTAssertEqual(project.bookmarks.count, 2)
        XCTAssertEqual(project.bookmarks[0].query, "SELECT 2")
        XCTAssertEqual(project.bookmarks[1].query, "SELECT 1")
    }

    func testAddBookmarkDeduplicatesByConnectionAndQuery() {
        let b1 = TestFixtures.bookmark(
            connectionID: connectionID,
            databaseName: "mydb",
            query: "SELECT * FROM users"
        )
        let b2 = TestFixtures.bookmark(
            connectionID: connectionID,
            databaseName: "mydb",
            query: "SELECT * FROM users"
        )

        repo.addBookmark(b1, to: &project)
        XCTAssertEqual(project.bookmarks.count, 1)

        repo.addBookmark(b2, to: &project)
        XCTAssertEqual(project.bookmarks.count, 1, "Duplicate should replace, not add")
        XCTAssertEqual(project.bookmarks[0].id, b2.id)
    }

    // MARK: - Remove

    func testRemoveBookmark() {
        let bookmark = TestFixtures.bookmark(connectionID: connectionID, query: "SELECT 1")
        repo.addBookmark(bookmark, to: &project)
        XCTAssertEqual(project.bookmarks.count, 1)

        repo.removeBookmark(bookmark.id, from: &project)
        XCTAssertEqual(project.bookmarks.count, 0)
    }

    func testRemoveNonexistentBookmarkIsNoOp() {
        let bookmark = TestFixtures.bookmark(connectionID: connectionID)
        repo.addBookmark(bookmark, to: &project)

        repo.removeBookmark(UUID(), from: &project)
        XCTAssertEqual(project.bookmarks.count, 1)
    }

    // MARK: - Update

    func testUpdateBookmarkAppliesClosure() {
        let bookmark = TestFixtures.bookmark(connectionID: connectionID, title: "Old", query: "SELECT 1")
        repo.addBookmark(bookmark, to: &project)

        repo.updateBookmark(bookmark.id, in: &project) { b in
            b.title = "New Title"
        }

        XCTAssertEqual(project.bookmarks[0].title, "New Title")
    }

    // MARK: - Filter

    func testBookmarksForConnectionFiltersCorrectly() {
        let otherConnectionID = UUID()
        let b1 = TestFixtures.bookmark(connectionID: connectionID, query: "SELECT 1")
        let b2 = TestFixtures.bookmark(connectionID: otherConnectionID, query: "SELECT 2")
        let b3 = TestFixtures.bookmark(connectionID: connectionID, query: "SELECT 3")

        repo.addBookmark(b1, to: &project)
        repo.addBookmark(b2, to: &project)
        repo.addBookmark(b3, to: &project)

        let filtered = repo.bookmarks(for: connectionID, in: project)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.connectionID == connectionID })
    }

    func testBookmarksForConnectionSortsByDate() {
        let older = Date().addingTimeInterval(-100)
        let newer = Date()
        let b1 = TestFixtures.bookmark(connectionID: connectionID, query: "old", createdAt: older)
        let b2 = TestFixtures.bookmark(connectionID: connectionID, query: "new", createdAt: newer)

        repo.addBookmark(b1, to: &project)
        repo.addBookmark(b2, to: &project)

        let filtered = repo.bookmarks(for: connectionID, in: project)
        XCTAssertEqual(filtered[0].query, "new")
        XCTAssertEqual(filtered[1].query, "old")
    }
}
