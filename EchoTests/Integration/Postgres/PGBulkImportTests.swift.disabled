import XCTest
@testable import Echo

/// Integration tests for PostgreSQL bulk import via batched INSERT statements.
///
/// Verifies that the generic import path (used for Postgres, SQLite, MySQL)
/// correctly inserts CSV and XLSX data into real PostgreSQL tables.
final class PGBulkImportTests: PostgresDockerTestCase {

    // MARK: - CSV Import via executeUpdate

    func testImportCSVIntoTable() async throws {
        try await withTempTable(columns: "id INTEGER, name TEXT, email TEXT") { tableName in
            let csv = "id,name,email\n1,Alice,alice@example.com\n2,Bob,bob@example.com\n3,Charlie,charlie@test.org"
            let url = try writeTempCSV(content: csv)

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
            XCTAssertEqual(parsed.totalRowCount, 3)

            let columns = ["id", "name", "email"]
            let sql = buildInsertSQL(schema: "public", table: tableName, columns: columns, rows: parsed.rows)
            // TODO: postgres-wire doesn't parse command completion tags for affected row counts yet
            _ = try await execute(sql)

            let result = try await query("SELECT * FROM public.\(tableName) ORDER BY id")
            XCTAssertEqual(result.rows.count, 3)
            XCTAssertEqual(result.rows[0][1], "Alice")
            XCTAssertEqual(result.rows[2][2], "charlie@test.org")
        }
    }

    func testImportCSVWithSpecialCharacters() async throws {
        try await withTempTable(columns: "id INTEGER, data TEXT") { tableName in
            let csv = "id,data\n1,\"hello, world\"\n2,\"it's a test\"\n3,\"line1\nline2\""
            let url = try writeTempCSV(content: csv)

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
            let sql = buildInsertSQL(schema: "public", table: tableName, columns: ["id", "data"], rows: parsed.rows)
            try await execute(sql)

            let result = try await query("SELECT data FROM public.\(tableName) ORDER BY id")
            XCTAssertEqual(result.rows[0][0], "hello, world")
            XCTAssertEqual(result.rows[1][0], "it''s a test".replacingOccurrences(of: "''", with: "'"))
        }
    }

    func testImportCSVBatchedInsert() async throws {
        try await withTempTable(columns: "id INTEGER, value TEXT") { tableName in
            // Generate 150 rows to test batching (batch size of 50)
            var csvLines = ["id,value"]
            for i in 0..<150 {
                csvLines.append("\(i),val_\(i)")
            }
            let url = try writeTempCSV(content: csvLines.joined(separator: "\n"))

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
            XCTAssertEqual(parsed.totalRowCount, 150)

            // Import in batches of 50
            let batchSize = 50
            let columns = ["id", "value"]
            for batchStart in stride(from: 0, to: parsed.rows.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, parsed.rows.count)
                let batchRows = Array(parsed.rows[batchStart..<batchEnd])
                let sql = buildInsertSQL(schema: "public", table: tableName, columns: columns, rows: batchRows)
                try await execute(sql)
            }

            let countResult = try await query("SELECT COUNT(*) FROM public.\(tableName)")
            XCTAssertEqual(countResult.rows[0][0], "150")
        }
    }

    func testImportCSVWithEmptyValues() async throws {
        try await withTempTable(columns: "id INTEGER, name TEXT, note TEXT") { tableName in
            let csv = "id,name,note\n1,Alice,\n2,,hello\n3,,"
            let url = try writeTempCSV(content: csv)

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
            let sql = buildInsertSQL(schema: "public", table: tableName, columns: ["id", "name", "note"], rows: parsed.rows)
            try await execute(sql)

            let result = try await query("SELECT * FROM public.\(tableName) ORDER BY id")
            XCTAssertEqual(result.rows.count, 3)
            // Empty values become NULL via the import SQL
            XCTAssertNil(result.rows[0][2]) // Alice's note is empty → NULL
            XCTAssertNil(result.rows[1][1]) // Row 2 name is empty → NULL
        }
    }

    // MARK: - XLSX Import

    func testImportXLSXIntoTable() async throws {
        try await withTempTable(columns: "id INTEGER, name TEXT, score NUMERIC") { tableName in
            let headers = ["id", "name", "score"]
            let rows: [[String?]] = [["1", "Alice", "95.5"], ["2", "Bob", "87.0"], ["3", "Charlie", "92.3"]]

            let url = try await writeTestXLSX(headers: headers, rows: rows)

            let parsed = try await XLSXFileParser.parse(url: url)
            XCTAssertEqual(parsed.totalRowCount, 3)

            let sql = buildInsertSQL(schema: "public", table: tableName, columns: headers, rows: parsed.rows)
            try await execute(sql)

            let result = try await query("SELECT * FROM public.\(tableName) ORDER BY id")
            XCTAssertEqual(result.rows.count, 3)
            XCTAssertEqual(result.rows[0][1], "Alice")
        }
    }

    // MARK: - Column Mapping

    func testPartialColumnMapping() async throws {
        try await withTempTable(columns: "name TEXT, city TEXT") { tableName in
            // CSV has 3 columns but we only import 2
            let csv = "name,age,city\nAlice,30,NYC\nBob,25,LA"
            let url = try writeTempCSV(content: csv)

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)

            // Map only column 0 (name) and column 2 (city), skip column 1 (age)
            let mappedRows = parsed.rows.map { row in
                [row[0], row[2]]
            }

            let sql = buildInsertSQL(schema: "public", table: tableName, columns: ["name", "city"], rows: mappedRows)
            try await execute(sql)

            let result = try await query("SELECT * FROM public.\(tableName) ORDER BY name")
            XCTAssertEqual(result.rows.count, 2)
            XCTAssertEqual(result.rows[0][0], "Alice")
            XCTAssertEqual(result.rows[0][1], "NYC")
        }
    }

    // MARK: - Tab-Delimited Import

    func testImportTSVIntoTable() async throws {
        try await withTempTable(columns: "id INTEGER, name TEXT") { tableName in
            let tsv = "id\tname\n1\tAlice\n2\tBob"
            let url = try writeTempCSV(content: tsv, filename: "test.tsv")

            let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .tab)
            let sql = buildInsertSQL(schema: "public", table: tableName, columns: ["id", "name"], rows: parsed.rows)
            try await execute(sql)

            let result = try await query("SELECT * FROM public.\(tableName) ORDER BY id")
            XCTAssertEqual(result.rows.count, 2)
            XCTAssertEqual(result.rows[1][1], "Bob")
        }
    }

    // MARK: - Helpers

    private func writeTempCSV(content: String, filename: String = "test.csv") throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_" + filename)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func writeTestXLSX(headers: [String], rows: [[String?]]) async throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let fileURL = URL(fileURLWithPath: tempDir)
            .appendingPathComponent(UUID().uuidString + "_test.xlsx")
        try await XLSXExportWriter.write(headers: headers, rows: rows, to: fileURL)
        return fileURL
    }

    /// Builds a multi-row INSERT statement matching BulkImportViewModel.buildInsertSQL.
    private func buildInsertSQL(schema: String?, table: String, columns: [String], rows: [[String]]) -> String {
        let quotedTable: String
        if let schema {
            quotedTable = "\"\(schema)\".\"\(table)\""
        } else {
            quotedTable = "\"\(table)\""
        }
        let quotedColumns = columns.map { "\"\($0)\"" }.joined(separator: ", ")

        let valueRows = rows.map { row in
            let literals = row.map { value -> String in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return "NULL" }
                let escaped = trimmed.replacingOccurrences(of: "'", with: "''")
                return "'\(escaped)'"
            }
            return "(\(literals.joined(separator: ", ")))"
        }

        return "INSERT INTO \(quotedTable) (\(quotedColumns)) VALUES \(valueRows.joined(separator: ", "))"
    }
}
