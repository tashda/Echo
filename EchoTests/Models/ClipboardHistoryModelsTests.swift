import XCTest
@testable import Echo

final class ClipboardHistoryModelsTests: XCTestCase {

    // MARK: - Source Codable Round-Trip

    func testSourceQueryEditorCodableRoundTrip() throws {
        let source = ClipboardHistoryEntry.Source.queryEditor
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ClipboardHistoryEntry.Source.self, from: data)
        XCTAssertEqual(decoded, source)
    }

    func testSourceResultGridWithHeadersCodableRoundTrip() throws {
        let source = ClipboardHistoryEntry.Source.resultGrid(includeHeaders: true)
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ClipboardHistoryEntry.Source.self, from: data)
        XCTAssertEqual(decoded, source)
    }

    func testSourceResultGridWithoutHeadersCodableRoundTrip() throws {
        let source = ClipboardHistoryEntry.Source.resultGrid(includeHeaders: false)
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ClipboardHistoryEntry.Source.self, from: data)
        XCTAssertEqual(decoded, source)
    }

    // MARK: - Estimated Size

    func testEstimatedSizeInBytes() {
        let entry = TestFixtures.clipboardHistoryEntry(
            content: "SELECT * FROM users",
            metadata: ClipboardHistoryEntry.Metadata(
                serverName: "prod-server",
                databaseName: "mydb",
                objectName: "users"
            )
        )

        let size = entry.estimatedSizeInBytes
        let contentSize = "SELECT * FROM users".utf8.count
        let serverSize = "prod-server".utf8.count
        let dbSize = "mydb".utf8.count
        let objSize = "users".utf8.count

        XCTAssertEqual(size, contentSize + serverSize + dbSize + objSize + 128)
    }

    func testEstimatedSizeWithEmptyMetadata() {
        let entry = TestFixtures.clipboardHistoryEntry(
            content: "SELECT 1",
            metadata: .empty
        )

        let size = entry.estimatedSizeInBytes
        XCTAssertEqual(size, "SELECT 1".utf8.count + 128)
    }

    // MARK: - Preview Text

    func testPreviewTextTruncatesAt140Chars() {
        let longContent = String(repeating: "a", count: 200)
        let entry = TestFixtures.clipboardHistoryEntry(content: longContent)
        XCTAssertLessThanOrEqual(entry.previewText.count, 141) // 140 + "…"
        XCTAssertTrue(entry.previewText.hasSuffix("…"))
    }

    func testPreviewTextDoesNotTruncateShortContent() {
        let entry = TestFixtures.clipboardHistoryEntry(content: "SELECT 1")
        XCTAssertEqual(entry.previewText, "SELECT 1")
    }

    func testPreviewTextReplacesNewlines() {
        let entry = TestFixtures.clipboardHistoryEntry(content: "line1\nline2\nline3")
        XCTAssertTrue(entry.previewText.contains("⏎"))
        XCTAssertFalse(entry.previewText.contains("\n"))
    }

    // MARK: - Entry Codable Round-Trip

    func testEntryCodableRoundTrip() throws {
        let entry = TestFixtures.clipboardHistoryEntry(
            source: .resultGrid(includeHeaders: true),
            content: "id\tname\n1\tAlice",
            metadata: ClipboardHistoryEntry.Metadata(serverName: "srv", databaseName: "db")
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ClipboardHistoryEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.source, .resultGrid(includeHeaders: true))
        XCTAssertEqual(decoded.content, "id\tname\n1\tAlice")
        XCTAssertEqual(decoded.metadata.serverName, "srv")
        XCTAssertEqual(decoded.metadata.databaseName, "db")
    }

    // MARK: - Metadata

    func testMetadataHasDetailsWhenPopulated() {
        let meta = ClipboardHistoryEntry.Metadata(serverName: "prod")
        XCTAssertTrue(meta.hasDetails)
    }

    func testMetadataHasNoDetailsWhenEmpty() {
        XCTAssertFalse(ClipboardHistoryEntry.Metadata.empty.hasDetails)
    }

    func testMetadataHasNoDetailsWhenWhitespaceOnly() {
        let meta = ClipboardHistoryEntry.Metadata(serverName: "   ", databaseName: "  ")
        XCTAssertFalse(meta.hasDetails)
    }

    // MARK: - Usage Breakdown

    func testUsageBreakdownTotalBytes() {
        let breakdown = ClipboardHistoryUsageBreakdown(queryBytes: 100, gridBytes: 200)
        XCTAssertEqual(breakdown.totalBytes, 300)
    }
}
