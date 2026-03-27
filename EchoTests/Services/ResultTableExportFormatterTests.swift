import Foundation
import Testing
@testable import Echo

@Suite("ResultTableExportFormatter")
struct ResultTableExportFormatterTests {
    let headers = ["id", "name", "email"]
    let rows: [[String?]] = [
        ["1", "Alice", "alice@example.com"],
        ["2", "Bob", nil],
        ["3", "Charlie", "charlie@example.com"],
    ]

    // MARK: - TSV

    @Test func tsvIncludesHeaders() {
        let result = ResultTableExportFormatter.formatTSV(headers: headers, rows: rows, includeHeaders: true)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "id\tname\temail")
    }

    @Test func tsvOmitsHeadersWhenDisabled() {
        let result = ResultTableExportFormatter.formatTSV(headers: headers, rows: rows, includeHeaders: false)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "1\tAlice\talice@example.com")
    }

    @Test func tsvRendersNilAsEmpty() {
        let result = ResultTableExportFormatter.formatTSV(headers: headers, rows: rows, includeHeaders: false)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[1] == "2\tBob\t")
    }

    @Test func tsvEmptyRows() {
        let result = ResultTableExportFormatter.formatTSV(headers: headers, rows: [], includeHeaders: true)
        #expect(result == "id\tname\temail")
    }

    // MARK: - CSV

    @Test func csvBasicOutput() {
        let result = ResultTableExportFormatter.formatCSV(headers: ["col"], rows: [["value"]])
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "col")
        #expect(lines[1] == "value")
    }

    @Test func csvEscapesCommas() {
        let result = ResultTableExportFormatter.formatCSV(headers: ["data"], rows: [["hello, world"]])
        let lines = result.components(separatedBy: "\n")
        #expect(lines[1] == "\"hello, world\"")
    }

    @Test func csvEscapesQuotes() {
        let result = ResultTableExportFormatter.formatCSV(headers: ["data"], rows: [["say \"hi\""]])
        let lines = result.components(separatedBy: "\n")
        #expect(lines[1] == "\"say \"\"hi\"\"\"")
    }

    @Test func csvEscapesNewlines() {
        let result = ResultTableExportFormatter.formatCSV(headers: ["data"], rows: [["line1\nline2"]])
        // The escaped value should be quoted
        #expect(result.contains("\"line1"))
    }

    @Test func csvNilBecomesEmpty() {
        let result = ResultTableExportFormatter.formatCSV(headers: ["a"], rows: [[nil]])
        let lines = result.components(separatedBy: "\n")
        #expect(lines[1] == "")
    }

    // MARK: - JSON

    @Test func jsonProducesValidArray() throws {
        let result = ResultTableExportFormatter.formatJSON(headers: ["id", "name"], rows: [["1", "Alice"]])
        let data = try #require(result.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(parsed.count == 1)
        #expect(parsed[0]["id"] as? String == "1")
        #expect(parsed[0]["name"] as? String == "Alice")
    }

    @Test func jsonHandlesNilValues() throws {
        let result = ResultTableExportFormatter.formatJSON(headers: ["a"], rows: [[nil]])
        let data = try #require(result.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any?]])
        #expect(parsed.count == 1)
    }

    @Test func jsonEmptyRowsProducesEmptyArray() {
        let result = ResultTableExportFormatter.formatJSON(headers: ["a"], rows: [])
        #expect(result == "[\n\n]")
    }

    // MARK: - SQL INSERT

    @Test func sqlInsertGeneratesStatements() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "users", headers: ["id", "name"], rows: [["1", "Alice"]]
        )
        #expect(result.contains("INSERT INTO \"users\""))
        #expect(result.contains("(\"id\", \"name\")"))
        #expect(result.contains("VALUES (1, 'Alice')"))
    }

    @Test func sqlInsertEscapesSingleQuotes() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["val"], rows: [["it's a test"]]
        )
        #expect(result.contains("'it''s a test'"))
    }

    @Test func sqlInsertRendersNullForNil() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["val"], rows: [[nil]]
        )
        #expect(result.contains("NULL"))
    }

    @Test func sqlInsertRendersNullForNULLString() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["val"], rows: [["NULL"]]
        )
        #expect(result.contains("VALUES (NULL)"))
    }

    @Test func sqlInsertPreservesNumbers() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["int_val", "float_val"], rows: [["42", "3.14"]]
        )
        #expect(result.contains("42"))
        #expect(result.contains("3.14"))
        // Numbers should NOT be quoted
        #expect(!result.contains("'42'"))
        #expect(!result.contains("'3.14'"))
    }

    @Test func sqlInsertHandlesBooleans() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["flag"], rows: [["true"]]
        )
        #expect(result.contains("TRUE"))
    }

    @Test func sqlInsertEmptyRowsReturnsEmpty() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "t", headers: ["a"], rows: []
        )
        #expect(result.isEmpty)
    }

    // MARK: - Markdown

    @Test func markdownGeneratesTable() {
        let result = ResultTableExportFormatter.formatMarkdown(
            headers: ["id", "name"], rows: [["1", "Alice"]]
        )
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "| id | name |")
        #expect(lines[1] == "| --- | --- |")
        #expect(lines[2] == "| 1 | Alice |")
    }

    @Test func markdownEscapesPipes() {
        let result = ResultTableExportFormatter.formatMarkdown(
            headers: ["data"], rows: [["a|b"]]
        )
        #expect(result.contains("a\\|b"))
    }

    @Test func markdownRendersNilAsNULL() {
        let result = ResultTableExportFormatter.formatMarkdown(
            headers: ["val"], rows: [[nil]]
        )
        #expect(result.contains("NULL"))
    }

    // MARK: - Format Dispatch

    @Test func formatDispatchesByType() {
        let tsv = ResultTableExportFormatter.format(.tsv, headers: ["a"], rows: [["1"]])
        #expect(tsv.contains("\t") || tsv == "a\n1") // TSV uses tabs

        let csv = ResultTableExportFormatter.format(.csv, headers: ["a"], rows: [["1"]])
        #expect(!csv.contains("\t"))

        let json = ResultTableExportFormatter.format(.json, headers: ["a"], rows: [["1"]])
        #expect(json.contains("["))

        let md = ResultTableExportFormatter.format(.markdown, headers: ["a"], rows: [["1"]])
        #expect(md.contains("|"))

        let sql = ResultTableExportFormatter.format(.sqlInsert, headers: ["a"], rows: [["1"]])
        #expect(sql.contains("INSERT"))
    }

    @Test func formatUsesProvidedTableName() {
        let result = ResultTableExportFormatter.format(
            .sqlInsert, headers: ["a"], rows: [["1"]], tableName: "my_table"
        )
        #expect(result.contains("\"my_table\""))
    }

    @Test func sqlInsertUsesMySQLIdentifierQuoting() {
        let result = ResultTableExportFormatter.formatSQLInsert(
            tableName: "users",
            headers: ["id", "display_name"],
            rows: [["1", "Alice"]],
            databaseType: .mysql
        )
        #expect(result.contains("INSERT INTO `users`"))
        #expect(result.contains("(`id`, `display_name`)"))
    }
}
