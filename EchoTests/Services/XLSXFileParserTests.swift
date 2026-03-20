import Foundation
import Testing
@testable import Echo

@Suite("XLSXFileParser", .serialized)
struct XLSXFileParserTests {

    /// Creates a minimal valid xlsx file at a temp path using XLSXExportWriter.
    private func writeTestXLSX(
        headers: [String],
        rows: [[String?]],
        filename: String = "test.xlsx"
    ) async throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_" + filename)
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: fileURL)
        return fileURL
    }

    // MARK: - Basic Parsing

    @Test func parseBasicXLSX() async throws {
        let url = try await writeTestXLSX(
            headers: ["name", "age", "city"],
            rows: [["Alice", "30", "NYC"], ["Bob", "25", "LA"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.headers == ["name", "age", "city"])
        #expect(result.rows.count == 2)
        #expect(result.totalRowCount == 2)
        #expect(result.rows[0][0] == "Alice")
        #expect(result.rows[1][0] == "Bob")
    }

    @Test func parseSingleRow() async throws {
        let url = try await writeTestXLSX(
            headers: ["id", "value"],
            rows: [["1", "hello"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.headers == ["id", "value"])
        #expect(result.rows.count == 1)
        #expect(result.rows[0] == ["1", "hello"])
    }

    @Test func parseSingleColumn() async throws {
        let url = try await writeTestXLSX(
            headers: ["name"],
            rows: [["Alice"], ["Bob"], ["Charlie"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.headers == ["name"])
        #expect(result.rows.count == 3)
        #expect(result.rows[2] == ["Charlie"])
    }

    // MARK: - Preview Limit

    @Test func previewLimitReturnsLimitedRows() async throws {
        let rows = (0..<20).map { ["\($0)", "value_\($0)"] as [String?] }
        let url = try await writeTestXLSX(headers: ["id", "val"], rows: rows)
        let result = try await XLSXFileParser.parse(url: url, previewLimit: 5)
        #expect(result.rows.count == 5)
        #expect(result.totalRowCount == 20)
        #expect(result.rows[0][0] == "0")
        #expect(result.rows[4][0] == "4")
    }

    @Test func previewLimitLargerThanRowCount() async throws {
        let url = try await writeTestXLSX(
            headers: ["id"],
            rows: [["1"], ["2"], ["3"]]
        )
        let result = try await XLSXFileParser.parse(url: url, previewLimit: 100)
        #expect(result.rows.count == 3)
        #expect(result.totalRowCount == 3)
    }

    @Test func previewLimitNilReturnsAll() async throws {
        let rows = (0..<50).map { ["\($0)"] as [String?] }
        let url = try await writeTestXLSX(headers: ["id"], rows: rows)
        let result = try await XLSXFileParser.parse(url: url, previewLimit: nil)
        #expect(result.rows.count == 50)
        #expect(result.totalRowCount == 50)
    }

    // MARK: - Data Types

    @Test func numericValuesPreserved() async throws {
        let url = try await writeTestXLSX(
            headers: ["int_val", "float_val"],
            rows: [["42", "3.14"], ["0", "-1.5"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows.count == 2)
        // Numeric values may come back as numbers from xlsx
        #expect(result.rows[0][0] == "42")
        #expect(result.rows[0][1] == "3.14")
    }

    @Test func stringValuesPreserved() async throws {
        let url = try await writeTestXLSX(
            headers: ["text"],
            rows: [["hello world"], ["foo bar"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows[0][0] == "hello world")
        #expect(result.rows[1][0] == "foo bar")
    }

    // MARK: - Special Characters

    @Test func xmlSpecialCharactersEscaped() async throws {
        let url = try await writeTestXLSX(
            headers: ["data"],
            rows: [["<script>alert('xss')</script>"], ["A & B"], ["\"quoted\""]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows[0][0] == "<script>alert('xss')</script>")
        #expect(result.rows[1][0] == "A & B")
        #expect(result.rows[2][0] == "\"quoted\"")
    }

    @Test func unicodeContent() async throws {
        let url = try await writeTestXLSX(
            headers: ["greeting"],
            rows: [["\u{4f60}\u{597d}"], ["\u{3053}\u{3093}\u{306b}\u{3061}\u{306f}"], ["\u{00e9}\u{00e8}\u{00ea}"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows[0][0] == "\u{4f60}\u{597d}")
        #expect(result.rows[1][0] == "\u{3053}\u{3093}\u{306b}\u{3061}\u{306f}")
        #expect(result.rows[2][0] == "\u{00e9}\u{00e8}\u{00ea}")
    }

    // MARK: - Empty Data

    @Test func emptyRowsHandled() async throws {
        let url = try await writeTestXLSX(
            headers: ["a", "b"],
            rows: [["1", "2"], [nil, nil], ["3", "4"]]
        )
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows.count == 3)
    }

    @Test func headersOnlyNoDataRows() async throws {
        let url = try await writeTestXLSX(headers: ["col1", "col2"], rows: [])
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.headers == ["col1", "col2"])
        #expect(result.rows.isEmpty)
        #expect(result.totalRowCount == 0)
    }

    // MARK: - Error Cases

    @Test func nonexistentFileThrowsError() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).xlsx")
        do {
            _ = try await XLSXFileParser.parse(url: fakeURL)
            Issue.record("Expected error for nonexistent file")
        } catch {
            #expect(error is XLSXParseError || error is CocoaError || error is NSError)
        }
    }

    @Test func invalidFileThrowsError() async throws {
        // Write a plain text file with .xlsx extension
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_fake.xlsx")
        try "not a real xlsx".write(to: fileURL, atomically: true, encoding: .utf8)

        do {
            _ = try await XLSXFileParser.parse(url: fileURL)
            Issue.record("Expected error for invalid xlsx file")
        } catch {
            // Any error is acceptable for a corrupted file
        }
    }

    // MARK: - Large Data Set

    @Test func parseLargeRowCount() async throws {
        let rows = (0..<200).map { ["\($0)", "name_\($0)", "value_\($0)"] as [String?] }
        let url = try await writeTestXLSX(headers: ["id", "name", "value"], rows: rows)
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.rows.count == 200)
        #expect(result.totalRowCount == 200)
        #expect(result.rows[199][0] == "199")
    }

    // MARK: - Many Columns

    @Test func parseManyColumns() async throws {
        let colCount = 26
        let headers = (0..<colCount).map { "col_\($0)" }
        let row = (0..<colCount).map { "val_\($0)" as String? }
        let url = try await writeTestXLSX(headers: headers, rows: [row])
        let result = try await XLSXFileParser.parse(url: url)
        #expect(result.headers.count == colCount)
        #expect(result.rows[0].count == colCount)
        #expect(result.rows[0][25] == "val_25")
    }
}
