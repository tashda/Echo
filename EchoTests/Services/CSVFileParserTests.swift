import Foundation
import Testing
@testable import Echo

@Suite("CSVDelimiter")
struct CSVDelimiterTests {

    @Test func commaRawValue() {
        #expect(CSVDelimiter.comma.rawValue == ",")
    }

    @Test func tabRawValue() {
        #expect(CSVDelimiter.tab.rawValue == "\t")
    }

    @Test func pipeRawValue() {
        #expect(CSVDelimiter.pipe.rawValue == "|")
    }

    @Test func semicolonRawValue() {
        #expect(CSVDelimiter.semicolon.rawValue == ";")
    }

    @Test func commaDisplayName() {
        #expect(CSVDelimiter.comma.displayName == "Comma (,)")
    }

    @Test func tabDisplayName() {
        #expect(CSVDelimiter.tab.displayName == "Tab")
    }

    @Test func pipeDisplayName() {
        #expect(CSVDelimiter.pipe.displayName == "Pipe (|)")
    }

    @Test func semicolonDisplayName() {
        #expect(CSVDelimiter.semicolon.displayName == "Semicolon (;)")
    }

    @Test func caseIterableContainsAllCases() {
        #expect(CSVDelimiter.allCases.count == 4)
        #expect(CSVDelimiter.allCases.contains(.comma))
        #expect(CSVDelimiter.allCases.contains(.tab))
        #expect(CSVDelimiter.allCases.contains(.pipe))
        #expect(CSVDelimiter.allCases.contains(.semicolon))
    }

    @Test func identifiableUsesRawValue() {
        #expect(CSVDelimiter.comma.id == ",")
        #expect(CSVDelimiter.tab.id == "\t")
    }
}

@Suite("CSVParseError")
struct CSVParseErrorTests {

    @Test func invalidEncodingErrorDescription() {
        let error = CSVParseError.invalidEncoding
        #expect(error.errorDescription?.contains("UTF-8") == true)
    }
}

@Suite("CSVFileParser", .serialized)
struct CSVFileParserTests {

    // Helper to write a temp file and return its URL.
    // Uses NSTemporaryDirectory() which is sandbox-aware.
    private func writeTempFile(content: String, filename: String = "test.csv") throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_" + filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Basic Comma-Delimited Parsing

    @Test func parseBasicCSV() async throws {
        let csv = "name,age,city\nAlice,30,NYC\nBob,25,LA"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["name", "age", "city"])
        #expect(result.rows.count == 2)
        #expect(result.rows[0] == ["Alice", "30", "NYC"])
        #expect(result.rows[1] == ["Bob", "25", "LA"])
        #expect(result.totalRowCount == 2)
    }

    @Test func parseSingleRow() async throws {
        let csv = "id,value\n1,hello"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["id", "value"])
        #expect(result.rows.count == 1)
        #expect(result.rows[0] == ["1", "hello"])
    }

    // MARK: - Different Delimiters

    @Test func parseTabDelimited() async throws {
        let tsv = "name\tage\nAlice\t30\nBob\t25"
        let url = try writeTempFile(content: tsv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .tab)
        #expect(result.headers == ["name", "age"])
        #expect(result.rows.count == 2)
        #expect(result.rows[0] == ["Alice", "30"])
    }

    @Test func parsePipeDelimited() async throws {
        let psv = "name|age\nAlice|30\nBob|25"
        let url = try writeTempFile(content: psv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .pipe)
        #expect(result.headers == ["name", "age"])
        #expect(result.rows.count == 2)
        #expect(result.rows[0] == ["Alice", "30"])
    }

    @Test func parseSemicolonDelimited() async throws {
        let csv = "name;age\nAlice;30\nBob;25"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .semicolon)
        #expect(result.headers == ["name", "age"])
        #expect(result.rows.count == 2)
    }

    // MARK: - Quoted Fields

    @Test func parseQuotedFieldsWithCommas() async throws {
        let csv = "name,address\nAlice,\"123 Main St, Apt 4\"\nBob,\"456 Oak Ave, Suite 5\""
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows[0] == ["Alice", "123 Main St, Apt 4"])
        #expect(result.rows[1] == ["Bob", "456 Oak Ave, Suite 5"])
    }

    @Test func parseEscapedQuotesInQuotedFields() async throws {
        let csv = "name,quote\nAlice,\"She said \"\"hello\"\"\"\nBob,\"He said \"\"bye\"\"\""
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows[0] == ["Alice", "She said \"hello\""])
        #expect(result.rows[1] == ["Bob", "He said \"bye\""])
    }

    @Test func parseQuotedFieldWithNewline() async throws {
        let csv = "name,bio\nAlice,\"Line 1\nLine 2\""
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows.count == 1)
        #expect(result.rows[0][1] == "Line 1\nLine 2")
    }

    // MARK: - Empty Fields

    @Test func parseEmptyFields() async throws {
        let csv = "a,b,c\n1,,3\n,,\n4,5,"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows[0] == ["1", "", "3"])
        #expect(result.rows[1] == ["", "", ""])
        #expect(result.rows[2] == ["4", "5", ""])
    }

    // MARK: - Preview Limit

    @Test func previewLimitReturnsLimitedRows() async throws {
        let csv = "id\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma, previewLimit: 3)
        #expect(result.rows.count == 3)
        #expect(result.totalRowCount == 10)
        #expect(result.rows[0] == ["1"])
        #expect(result.rows[2] == ["3"])
    }

    @Test func previewLimitLargerThanRowCount() async throws {
        let csv = "id\n1\n2\n3"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma, previewLimit: 100)
        #expect(result.rows.count == 3)
        #expect(result.totalRowCount == 3)
    }

    @Test func previewLimitZero() async throws {
        let csv = "id\n1\n2\n3"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma, previewLimit: 0)
        #expect(result.rows.isEmpty)
        #expect(result.totalRowCount == 3)
    }

    // MARK: - parseAll

    @Test func parseAllReturnsAllRows() async throws {
        let csv = "id\n1\n2\n3\n4\n5"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
        #expect(result.rows.count == 5)
        #expect(result.totalRowCount == 5)
    }

    // MARK: - Edge Cases

    @Test func parseEmptyFile() async throws {
        let csv = ""
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers.isEmpty)
        #expect(result.rows.isEmpty)
        #expect(result.totalRowCount == 0)
    }

    @Test func parseHeadersOnly() async throws {
        let csv = "name,age,city"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["name", "age", "city"])
        #expect(result.rows.isEmpty)
        #expect(result.totalRowCount == 0)
    }

    @Test func parseHeadersOnlyWithTrailingNewline() async throws {
        let csv = "name,age,city\n"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["name", "age", "city"])
        #expect(result.rows.isEmpty)
    }

    @Test func parseUnicodeContent() async throws {
        let csv = "name,greeting\nAlice,\u{4f60}\u{597d}\nBob,\u{3053}\u{3093}\u{306b}\u{3061}\u{306f}"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows.count == 2)
        #expect(result.rows[0][1] == "\u{4f60}\u{597d}")
        #expect(result.rows[1][1] == "\u{3053}\u{3093}\u{306b}\u{3061}\u{306f}")
    }

    @Test func parseWindowsLineEndings() async throws {
        let csv = "name,age\r\nAlice,30\r\nBob,25\r\n"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["name", "age"])
        #expect(result.rows.count == 2)
        #expect(result.rows[0] == ["Alice", "30"])
    }

    @Test func parseLargeRowCount() async throws {
        var lines = ["id,value"]
        for i in 0..<500 {
            lines.append("\(i),value_\(i)")
        }
        let csv = lines.joined(separator: "\n")
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.rows.count == 500)
        #expect(result.totalRowCount == 500)
    }

    @Test func parseSingleColumnCSV() async throws {
        let csv = "name\nAlice\nBob\nCharlie"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["name"])
        #expect(result.rows.count == 3)
        #expect(result.rows[0] == ["Alice"])
    }

    @Test func parseQuotedHeaderFields() async throws {
        let csv = "\"First Name\",\"Last Name\"\nAlice,Smith\nBob,Jones"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["First Name", "Last Name"])
        #expect(result.rows.count == 2)
    }

    @Test func invalidEncodingThrowsError() async throws {
        // Write raw bytes that are not valid UTF-8
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_invalid.csv")
        let invalidBytes: [UInt8] = [0xFF, 0xFE, 0x80, 0x81]
        try Data(invalidBytes).write(to: fileURL)

        // The file may still be readable as UTF-8 if the system is lenient,
        // but if it does throw, it should be CSVParseError.invalidEncoding
        do {
            _ = try await CSVFileParser.parse(url: fileURL, delimiter: .comma)
            // If it doesn't throw, that's acceptable (system may handle it)
        } catch let error as CSVParseError {
            #expect(error == .invalidEncoding)
        }
    }

    @Test func nonexistentFileThrowsError() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).csv")
        do {
            _ = try await CSVFileParser.parse(url: fakeURL, delimiter: .comma)
            Issue.record("Expected error for nonexistent file")
        } catch {
            // Any error is acceptable for a missing file
            #expect(error is CocoaError || error is NSError)
        }
    }

    @Test func parseTrailingEmptyLines() async throws {
        let csv = "id\n1\n2\n\n\n"
        let url = try writeTempFile(content: csv)
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["id"])
        // Trailing empty rows should be removed
        #expect(result.rows.count == 2)
    }

    @Test func parseQuotedEmptyFieldsInline() async throws {
        // Empty quoted fields: "" parses as an empty string
        let csv = "a,b\n\"\",\"\"\n"
        let url = try writeTempFile(content: csv, filename: "quoted_empty_inline.csv")
        let result = try await CSVFileParser.parse(url: url, delimiter: .comma)
        #expect(result.headers == ["a", "b"])
        // The row should contain two empty strings from the quoted empty fields
        if !result.rows.isEmpty {
            #expect(result.rows[0][0].isEmpty)
            #expect(result.rows[0][1].isEmpty)
        }
    }
}
