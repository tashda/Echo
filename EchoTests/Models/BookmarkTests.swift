import XCTest
@testable import Echo

final class BookmarkTests: XCTestCase {

    // MARK: - Preview

    func testPreviewTruncatesAt160Chars() {
        let longQuery = String(repeating: "SELECT ", count: 30) // 210 chars
        let bookmark = TestFixtures.bookmark(query: longQuery)
        XCTAssertLessThanOrEqual(bookmark.preview.count, 161) // 160 + "…"
        XCTAssertTrue(bookmark.preview.hasSuffix("…"))
    }

    func testPreviewDoesNotTruncateShortQuery() {
        let bookmark = TestFixtures.bookmark(query: "SELECT 1")
        XCTAssertEqual(bookmark.preview, "SELECT 1")
        XCTAssertFalse(bookmark.preview.hasSuffix("…"))
    }

    func testPreviewReplacesNewlines() {
        let bookmark = TestFixtures.bookmark(query: "SELECT *\nFROM users\nWHERE id = 1")
        XCTAssertTrue(bookmark.preview.contains("⏎"))
        XCTAssertFalse(bookmark.preview.contains("\n"))
    }

    // MARK: - Primary Line

    func testPrimaryLineReturnsTitleWhenPresent() {
        let bookmark = TestFixtures.bookmark(title: "My Query", query: "SELECT * FROM users")
        XCTAssertEqual(bookmark.primaryLine, "My Query")
    }

    func testPrimaryLineReturnsFirstSQLLineWhenNoTitle() {
        let bookmark = TestFixtures.bookmark(title: nil, query: "SELECT *\nFROM users\nWHERE id = 1")
        XCTAssertEqual(bookmark.primaryLine, "SELECT *")
    }

    func testPrimaryLineTrimsWhitespace() {
        let bookmark = TestFixtures.bookmark(title: "  Trimmed  ", query: "SELECT 1")
        XCTAssertEqual(bookmark.primaryLine, "Trimmed")
    }

    func testPrimaryLineIgnoresEmptyTitle() {
        let bookmark = TestFixtures.bookmark(title: "   ", query: "SELECT 1 FROM dual")
        XCTAssertEqual(bookmark.primaryLine, "SELECT 1 FROM dual")
    }

    // MARK: - Grouped By Database

    func testGroupedByDatabaseGroupsCorrectly() {
        let connID = UUID()
        let bookmarks = [
            TestFixtures.bookmark(connectionID: connID, databaseName: "prod", query: "SELECT 1", createdAt: Date()),
            TestFixtures.bookmark(connectionID: connID, databaseName: "prod", query: "SELECT 2", createdAt: Date().addingTimeInterval(-10)),
            TestFixtures.bookmark(connectionID: connID, databaseName: "staging", query: "SELECT 3", createdAt: Date()),
            TestFixtures.bookmark(connectionID: connID, databaseName: nil, query: "SELECT 4", createdAt: Date()),
        ]

        let groups = bookmarks.groupedByDatabase()

        // Named databases first (sorted), then unknown last
        let namedGroups = groups.filter { $0.databaseName != nil }
        let unknownGroups = groups.filter { $0.databaseName == nil }

        XCTAssertEqual(namedGroups.count, 2)
        XCTAssertEqual(unknownGroups.count, 1)

        // Named groups sorted alphabetically
        XCTAssertEqual(namedGroups[0].databaseName, "prod")
        XCTAssertEqual(namedGroups[0].bookmarks.count, 2)
        XCTAssertEqual(namedGroups[1].databaseName, "staging")

        // Unknown group at the end
        XCTAssertEqual(unknownGroups[0].bookmarks.count, 1)
    }

    func testGroupedByDatabaseSortsByCreatedAtDescending() {
        let connID = UUID()
        let older = Date().addingTimeInterval(-100)
        let newer = Date()
        let bookmarks = [
            TestFixtures.bookmark(connectionID: connID, databaseName: "db", query: "old", createdAt: older),
            TestFixtures.bookmark(connectionID: connID, databaseName: "db", query: "new", createdAt: newer),
        ]

        let groups = bookmarks.groupedByDatabase()
        XCTAssertEqual(groups[0].bookmarks[0].query, "new")
        XCTAssertEqual(groups[0].bookmarks[1].query, "old")
    }

    // MARK: - Codable

    func testBookmarkCodableRoundTrip() throws {
        let bookmark = TestFixtures.bookmark(
            title: "Test",
            query: "SELECT * FROM users",
            source: .savedQuery
        )

        let data = try JSONEncoder().encode(bookmark)
        let decoded = try JSONDecoder().decode(Bookmark.self, from: data)

        XCTAssertEqual(decoded.id, bookmark.id)
        XCTAssertEqual(decoded.title, "Test")
        XCTAssertEqual(decoded.query, "SELECT * FROM users")
        XCTAssertEqual(decoded.source, .savedQuery)
    }
}
