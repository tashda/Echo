import XCTest
@testable import Echo

/// Integration tests for SQLite bulk import via batched INSERT statements.
///
/// Uses in-memory SQLite — no Docker required.
final class SQLiteBulkImportTests: XCTestCase {

    private func makeInMemorySession() async throws -> DatabaseSession {
        let factory = SQLiteFactory()
        return try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(username: "", password: nil)
        )
    }

    // MARK: - CSV Import

    func testImportCSVIntoSQLite() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE items (id INTEGER, name TEXT, price TEXT)")

        let csv = "id,name,price\n1,Widget,9.99\n2,Gadget,19.99\n3,Doohickey,4.50"
        let url = try writeTempCSV(content: csv)

        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
        XCTAssertEqual(parsed.totalRowCount, 3)

        let sql = buildInsertSQL(table: "items", columns: ["id", "name", "price"], rows: parsed.rows)
        _ = try await session.executeUpdate(sql)

        let result = try await session.simpleQuery("SELECT * FROM items ORDER BY id")
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.rows[0][1], "Widget")
        XCTAssertEqual(result.rows[2][2], "4.50")
    }

    func testImportCSVBatchedSQLite() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE data (id INTEGER, value TEXT)")

        var csvLines = ["id,value"]
        for i in 0..<100 {
            csvLines.append("\(i),val_\(i)")
        }
        let url = try writeTempCSV(content: csvLines.joined(separator: "\n"))
        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)

        // Insert in batches of 25
        let batchSize = 25
        for batchStart in stride(from: 0, to: parsed.rows.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, parsed.rows.count)
            let batchRows = Array(parsed.rows[batchStart..<batchEnd])
            let sql = buildInsertSQL(table: "data", columns: ["id", "value"], rows: batchRows)
            _ = try await session.executeUpdate(sql)
        }

        let countResult = try await session.simpleQuery("SELECT COUNT(*) FROM data")
        XCTAssertEqual(countResult.rows[0][0], "100")
    }

    func testImportCSVWithEmptyValues() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE notes (id INTEGER, title TEXT, body TEXT)")

        let csv = "id,title,body\n1,Hello,\n2,,world\n3,,"
        let url = try writeTempCSV(content: csv)

        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
        let sql = buildInsertSQL(table: "notes", columns: ["id", "title", "body"], rows: parsed.rows)
        _ = try await session.executeUpdate(sql)

        let result = try await session.simpleQuery("SELECT * FROM notes ORDER BY id")
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertNil(result.rows[0][2]) // Empty → NULL
        XCTAssertNil(result.rows[1][1]) // Empty → NULL
    }

    func testImportCSVWithSpecialCharacters() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE strings (id INTEGER, data TEXT)")

        let csv = "id,data\n1,\"it's quoted\"\n2,\"has, comma\"\n3,normal"
        let url = try writeTempCSV(content: csv)

        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
        let sql = buildInsertSQL(table: "strings", columns: ["id", "data"], rows: parsed.rows)
        _ = try await session.executeUpdate(sql)

        let result = try await session.simpleQuery("SELECT data FROM strings ORDER BY id")
        XCTAssertEqual(result.rows[0][0], "it's quoted")
        XCTAssertEqual(result.rows[1][0], "has, comma")
        XCTAssertEqual(result.rows[2][0], "normal")
    }

    // MARK: - XLSX Import into SQLite

    func testImportXLSXIntoSQLite() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE products (id INTEGER, name TEXT, quantity INTEGER)")

        let headers = ["id", "name", "quantity"]
        let rows: [[String?]] = [["1", "Apple", "50"], ["2", "Banana", "30"]]
        let url = try await writeTestXLSX(headers: headers, rows: rows)

        let parsed = try await XLSXFileParser.parse(url: url)
        XCTAssertEqual(parsed.totalRowCount, 2)

        let sql = buildInsertSQL(table: "products", columns: headers, rows: parsed.rows)
        _ = try await session.executeUpdate(sql)

        let result = try await session.simpleQuery("SELECT * FROM products ORDER BY id")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][1], "Apple")
        XCTAssertEqual(result.rows[1][2], "30")
    }

    // MARK: - No Schema for SQLite

    func testInsertWithoutSchema() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE test (val TEXT)")

        // SQLite import should NOT use schema prefix
        let sql = buildInsertSQL(table: "test", columns: ["val"], rows: [["hello"]])
        XCTAssertFalse(sql.contains("\"public\""))
        XCTAssertTrue(sql.contains("\"test\""))

        _ = try await session.executeUpdate(sql)
        let result = try await session.simpleQuery("SELECT val FROM test")
        XCTAssertEqual(result.rows[0][0], "hello")
    }

    // MARK: - Tab-Delimited

    func testImportTSVIntoSQLite() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE tsv_data (id INTEGER, name TEXT)")

        let tsv = "id\tname\n1\tAlice\n2\tBob"
        let url = try writeTempCSV(content: tsv, filename: "test.tsv")

        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .tab)
        let sql = buildInsertSQL(table: "tsv_data", columns: ["id", "name"], rows: parsed.rows)
        _ = try await session.executeUpdate(sql)

        let result = try await session.simpleQuery("SELECT * FROM tsv_data ORDER BY id")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[1][1], "Bob")
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

    /// Builds a multi-row INSERT without schema (SQLite style).
    private func buildInsertSQL(table: String, columns: [String], rows: [[String]]) -> String {
        let quotedTable = "\"\(table)\""
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
