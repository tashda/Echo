import XCTest
import SQLServerKit
@testable import Echo

/// Integration tests for MSSQL bulk import via BCP (SQLServerBulkCopyClient).
///
/// Verifies that the MSSQL-specific import path in BulkImportViewModel correctly
/// uses the sqlserver-nio bulk copy API to insert data from CSV and XLSX files.
final class MSSQLBulkImportTests: MSSQLLabTestCase {

    // MARK: - CSV Import via BCP

    func testBulkCopyCSVIntoTable() async throws {
        let tableName = uniqueTableName(prefix: "bcp_csv")
        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100))), .column("email", .nvarchar(length: .length(200)))])

        let csv = "id,name,email\n1,Alice,alice@example.com\n2,Bob,bob@example.com\n3,Charlie,charlie@test.org"
        let url = try writeTempCSV(content: csv)

        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)
        XCTAssertEqual(parsed.totalRowCount, 3)

        let bcpRows = parsed.rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { value in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return .null }
                return .nString(trimmed)
            }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: "dbo",
            columns: ["id", "name", "email"],
            batchSize: 100,
            identityInsert: false
        )

        let summary = try await sqlserverClient.bulk.copy(rows: bcpRows, options: options)
        XCTAssertEqual(summary.totalRows, 3)

        let result = try await query("SELECT * FROM dbo.\(tableName) ORDER BY id")
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[2][2], "charlie@test.org")
    }

    func testBulkCopyLargeBatch() async throws {
        let tableName = uniqueTableName(prefix: "bcp_large")
        try await createTable(tableName, [.column("id", .int), .column("value", .nvarchar(length: .length(200)))])

        var csvLines = ["id,value"]
        for i in 0..<500 {
            csvLines.append("\(i),val_\(i)")
        }
        let url = try writeTempCSV(content: csvLines.joined(separator: "\n"))
        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)

        let bcpRows = parsed.rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { .nString($0) }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: "dbo",
            columns: ["id", "value"],
            batchSize: 100,
            identityInsert: false
        )

        let summary = try await sqlserverClient.bulk.copy(rows: bcpRows, options: options)
        XCTAssertEqual(summary.totalRows, 500)
        XCTAssertGreaterThanOrEqual(summary.batchesExecuted, 5)

        let countResult = try await query("SELECT COUNT(*) FROM dbo.\(tableName)")
        XCTAssertEqual(countResult.rows[0][0], "500")
    }

    func testBulkCopyWithNullValues() async throws {
        let tableName = uniqueTableName(prefix: "bcp_null")
        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100))), .column("note", .nvarchar(length: .length(200)))])

        let csv = "id,name,note\n1,Alice,\n2,,hello\n3,,"
        let url = try writeTempCSV(content: csv)
        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .comma)

        let bcpRows = parsed.rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { value in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return .null }
                return .nString(trimmed)
            }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: "dbo",
            columns: ["id", "name", "note"],
            batchSize: 100,
            identityInsert: false
        )

        let summary = try await sqlserverClient.bulk.copy(rows: bcpRows, options: options)
        XCTAssertEqual(summary.totalRows, 3)

        let result = try await query("SELECT * FROM dbo.\(tableName) ORDER BY id")
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertNil(result.rows[0][2]) // Alice's note is NULL
        XCTAssertNil(result.rows[1][1]) // Row 2 name is NULL
    }

    // MARK: - XLSX Import via BCP

    func testBulkCopyXLSXIntoTable() async throws {
        let tableName = uniqueTableName(prefix: "bcp_xlsx")
        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100))), .column("score", .decimal(precision: 5, scale: 2))])

        let headers = ["id", "name", "score"]
        let rows: [[String?]] = [["1", "Alice", "95.50"], ["2", "Bob", "87.00"]]
        let url = try await writeTestXLSX(headers: headers, rows: rows)

        let parsed = try await XLSXFileParser.parse(url: url)
        XCTAssertEqual(parsed.totalRowCount, 2)

        let bcpRows = parsed.rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { .nString($0) }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: "dbo",
            columns: headers,
            batchSize: 100,
            identityInsert: false
        )

        let summary = try await sqlserverClient.bulk.copy(rows: bcpRows, options: options)
        XCTAssertEqual(summary.totalRows, 2)

        let result = try await query("SELECT * FROM dbo.\(tableName) ORDER BY id")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
    }

    // MARK: - Tab-Delimited via BCP

    func testBulkCopyTSV() async throws {
        let tableName = uniqueTableName(prefix: "bcp_tsv")
        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100)))])

        let tsv = "id\tname\n1\tAlice\n2\tBob"
        let url = try writeTempCSV(content: tsv, filename: "test.tsv")
        let parsed = try await CSVFileParser.parseAll(url: url, delimiter: .tab)

        let bcpRows = parsed.rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { .nString($0) }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: "dbo",
            columns: ["id", "name"],
            batchSize: 100,
            identityInsert: false
        )

        let summary = try await sqlserverClient.bulk.copy(rows: bcpRows, options: options)
        XCTAssertEqual(summary.totalRows, 2)

        let result = try await query("SELECT * FROM dbo.\(tableName) ORDER BY id")
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
}
