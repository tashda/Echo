import XCTest
@testable import Echo

final class SQLFormatterTests: XCTestCase {
    private let formatter = SQLFormatter.shared

    // MARK: - PostgreSQL

    func testFormatPostgreSQLUppercasesKeywords() async throws {
        let sql = "select id, name from users where active = true"
        let formatted = try await formatter.format(sql: sql, dialect: .postgres)

        XCTAssertTrue(formatted.contains("SELECT"), "Keywords should be uppercased")
        XCTAssertTrue(formatted.contains("FROM"), "FROM should be uppercased")
        XCTAssertTrue(formatted.contains("WHERE"), "WHERE should be uppercased")
    }

    // MARK: - MySQL

    func testFormatMySQL() async throws {
        let sql = "select * from orders limit 10"
        let formatted = try await formatter.format(sql: sql, dialect: .mysql)

        XCTAssertTrue(formatted.contains("SELECT"))
        XCTAssertTrue(formatted.contains("LIMIT"))
    }

    // MARK: - SQLite

    func testFormatSQLite() async throws {
        let sql = "select * from items where rowid > 0"
        let formatted = try await formatter.format(sql: sql, dialect: .sqlite)

        XCTAssertTrue(formatted.contains("SELECT"))
    }

    // MARK: - MSSQL

    func testFormatMSSQL() async throws {
        let sql = "select top 10 * from dbo.users"
        let formatted = try await formatter.format(sql: sql, dialect: .microsoftSQL)

        XCTAssertTrue(formatted.contains("SELECT"))
    }

    // MARK: - DuckDB

    func testFormatDuckDB() async throws {
        let sql = "select * from read_parquet('data.parquet')"
        let formatted = try await formatter.format(sql: sql, dialect: .duckdb)

        XCTAssertTrue(formatted.contains("SELECT"))
    }

    // MARK: - Edge Cases

    func testEmptyInputReturnsEmpty() async throws {
        let formatted = try await formatter.format(sql: "", dialect: .postgres)
        XCTAssertTrue(formatted.isEmpty || formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testInvalidSQLDoesNotCrash() async throws {
        let sql = "NOT VALID SQL @@@ {{{}}})"
        let formatted = try await formatter.format(sql: sql, dialect: .postgres)
        // Should return something without crashing
        XCTAssertFalse(formatted.isEmpty)
    }

    func testMultiStatementFormatting() async throws {
        let sql = "select 1; select 2;"
        let formatted = try await formatter.format(sql: sql, dialect: .postgres)
        XCTAssertTrue(formatted.contains("SELECT"))
    }
}
