import Foundation
import Testing
@testable import Echo

@Suite("XLSXExportWriter", .serialized)
struct XLSXExportWriterTests {

    private func tempURL(filename: String = "export.xlsx") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + "_" + filename)
    }

    // MARK: - File Creation

    @Test func writesValidFile() async throws {
        let url = tempURL()
        try await XLSXExportWriter.write(
            headers: ["id", "name"],
            rows: [["1", "Alice"], ["2", "Bob"]],
            to: url
        )
        let data = try Data(contentsOf: url)
        // ZIP files start with PK signature (0x504B)
        #expect(data.count > 0)
        #expect(data[0] == 0x50) // 'P'
        #expect(data[1] == 0x4B) // 'K'
    }

    @Test func overwritesExistingFile() async throws {
        let url = tempURL()
        try "old content".write(to: url, atomically: true, encoding: .utf8)

        try await XLSXExportWriter.write(
            headers: ["a"],
            rows: [["1"]],
            to: url
        )

        let data = try Data(contentsOf: url)
        #expect(data[0] == 0x50) // Should be zip, not text
    }

    // MARK: - exportData

    @Test func exportDataReturnsValidZip() async throws {
        let data = try await XLSXExportWriter.exportData(
            headers: ["col"],
            rows: [["value"]]
        )
        #expect(data.count > 0)
        #expect(data[0] == 0x50)
        #expect(data[1] == 0x4B)
    }

    // MARK: - Content Integrity via Round-Trip

    @Test func roundTripBasicData() async throws {
        let headers = ["id", "name", "email"]
        let rows: [[String?]] = [
            ["1", "Alice", "alice@example.com"],
            ["2", "Bob", "bob@example.com"],
        ]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.headers == headers)
        #expect(parsed.totalRowCount == 2)
        #expect(parsed.rows[0][0] == "1")
        #expect(parsed.rows[0][1] == "Alice")
        #expect(parsed.rows[1][2] == "bob@example.com")
    }

    @Test func roundTripNumericValues() async throws {
        let headers = ["integer", "decimal", "negative"]
        let rows: [[String?]] = [["42", "3.14", "-100"]]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.rows[0][0] == "42")
        #expect(parsed.rows[0][1] == "3.14")
        #expect(parsed.rows[0][2] == "-100")
    }

    @Test func roundTripSpecialCharacters() async throws {
        let headers = ["data"]
        let rows: [[String?]] = [
            ["hello & goodbye"],
            ["<tag>value</tag>"],
            ["quote: \"test\""],
            ["apostrophe: it's"],
        ]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.rows[0][0] == "hello & goodbye")
        #expect(parsed.rows[1][0] == "<tag>value</tag>")
        #expect(parsed.rows[2][0] == "quote: \"test\"")
        #expect(parsed.rows[3][0] == "apostrophe: it's")
    }

    @Test func roundTripUnicode() async throws {
        let headers = ["text"]
        let rows: [[String?]] = [
            ["\u{4f60}\u{597d}"],       // Chinese
            ["\u{00e9}\u{00e8}\u{00ea}"], // French accents
            ["\u{1f600}"],               // Emoji
        ]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.rows[0][0] == "\u{4f60}\u{597d}")
        #expect(parsed.rows[1][0] == "\u{00e9}\u{00e8}\u{00ea}")
        #expect(parsed.rows[2][0] == "\u{1f600}")
    }

    @Test func roundTripEmptyRows() async throws {
        let headers = ["a", "b"]
        let rows: [[String?]] = [["1", "2"], [], ["3", "4"]]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        // Empty rows may be omitted in xlsx — at minimum first and last should survive
        #expect(parsed.totalRowCount >= 2)
    }

    @Test func roundTripNilValues() async throws {
        let headers = ["a", "b"]
        let rows: [[String?]] = [["1", nil], [nil, "2"]]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.totalRowCount == 2)
        // nil cells may become empty strings after round-trip
        #expect(parsed.rows[0][0] == "1")
        #expect(parsed.rows[1].last == "2")
    }

    @Test func roundTripLargeDataset() async throws {
        let headers = ["id", "name", "score"]
        let rows: [[String?]] = (0..<500).map { i in
            ["\(i)", "user_\(i)", "\(Double(i) * 1.5)"]
        }

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.headers == headers)
        #expect(parsed.totalRowCount == 500)
        #expect(parsed.rows[0][0] == "0")
        #expect(parsed.rows[499][1] == "user_499")
    }

    @Test func roundTripManyColumns() async throws {
        let colCount = 30
        let headers = (0..<colCount).map { "col\($0)" }
        let rows: [[String?]] = [
            (0..<colCount).map { "val\($0)" }
        ]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.headers.count == colCount)
        #expect(parsed.rows[0].count >= colCount)
    }

    // MARK: - Edge Cases

    @Test func emptyDataset() async throws {
        let url = tempURL()
        try await XLSXExportWriter.write(headers: ["a", "b"], rows: [], to: url)
        let parsed = try await XLSXFileParser.parse(url: url)
        #expect(parsed.headers == ["a", "b"])
        #expect(parsed.rows.isEmpty)
    }

    @Test func duplicateStringValues() async throws {
        let headers = ["status"]
        let rows: [[String?]] = [["active"], ["active"], ["inactive"], ["active"]]

        let url = tempURL()
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: url)
        let parsed = try await XLSXFileParser.parse(url: url)

        #expect(parsed.rows.count == 4)
        #expect(parsed.rows[0][0] == "active")
        #expect(parsed.rows[2][0] == "inactive")
    }
}
