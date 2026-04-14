import Testing
@testable import Echo
import EchoSense

@Suite("SQL Parser Bridge")
struct SQLParserBridgeTests {
    private let parser = SQLParserBridge.shared

    // MARK: - PostgreSQL

    @Test("Valid PostgreSQL SELECT parses successfully")
    func validPostgresSelect() {
        let result = parser.parseSync(sql: "SELECT id, name FROM users WHERE id = 1", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.error == nil)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: nil, table: "users")))
        #expect(result!.columnReferences.contains(SQLColumnReference(operation: "select", table: nil, column: "id")))
        #expect(result!.columnReferences.contains(SQLColumnReference(operation: "select", table: nil, column: "name")))
    }

    @Test("PostgreSQL schema-qualified table")
    func postgresSchemaQualified() {
        let result = parser.parseSync(sql: "SELECT * FROM public.users", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: "public", table: "users")))
    }

    @Test("PostgreSQL JOIN extracts both tables")
    func postgresJoin() {
        let result = parser.parseSync(sql: "SELECT u.id FROM users u JOIN orders o ON u.id = o.user_id", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.count == 2)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: nil, table: "users")))
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: nil, table: "orders")))
    }

    // MARK: - TransactSQL (MSSQL)

    @Test("Valid TransactSQL SELECT TOP")
    func validTransactSQL() {
        let result = parser.parseSync(sql: "SELECT TOP 10 * FROM dbo.users", dialect: .microsoftSQL)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: "dbo", table: "users")))
    }

    // MARK: - MySQL

    @Test("Valid MySQL with backtick identifiers")
    func validMySQL() {
        let result = parser.parseSync(sql: "SELECT * FROM `my_table` LIMIT 10", dialect: .mysql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: nil, table: "my_table")))
    }

    // MARK: - SQLite

    @Test("Valid SQLite query")
    func validSQLite() {
        let result = parser.parseSync(sql: "SELECT * FROM sqlite_master", dialect: .sqlite)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(SQLTableReference(operation: "select", schema: nil, table: "sqlite_master")))
    }

    // MARK: - Parse Errors

    @Test("Syntax error returns error with position")
    func syntaxError() {
        let result = parser.parseSync(sql: "SELECT FROM", dialect: .postgresql)
        #expect(result != nil)
        #expect(!result!.success)
        #expect(result!.error != nil)
        #expect(result!.error!.line != nil)
        #expect(result!.error!.column != nil)
        #expect(result!.error!.offset != nil)
    }

    @Test("Unclosed parenthesis returns error")
    func unclosedParen() {
        let result = parser.parseSync(sql: "SELECT (1 + 2", dialect: .postgresql)
        #expect(result != nil)
        #expect(!result!.success)
        #expect(result!.error != nil)
    }

    // MARK: - Multi-Statement

    @Test("Multi-statement SQL parses successfully")
    func multiStatement() {
        let result = parser.parseSync(sql: "SELECT 1; SELECT 2;", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
    }

    // MARK: - Edge Cases

    @Test("Empty SQL parses without crashing")
    func emptySQL() {
        let result = parser.parseSync(sql: "", dialect: .postgresql)
        #expect(result != nil)
        // node-sql-parser treats empty input as valid (empty AST)
    }

    @Test("INSERT extracts target table")
    func insertTable() {
        let result = parser.parseSync(sql: "INSERT INTO users (name) VALUES ('test')", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(where: { $0.table == "users" && $0.operation == "insert" }))
    }

    @Test("UPDATE extracts target table")
    func updateTable() {
        let result = parser.parseSync(sql: "UPDATE users SET name = 'test' WHERE id = 1", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(where: { $0.table == "users" && $0.operation == "update" }))
    }

    @Test("DELETE extracts target table")
    func deleteTable() {
        let result = parser.parseSync(sql: "DELETE FROM users WHERE id = 1", dialect: .postgresql)
        #expect(result != nil)
        #expect(result!.success)
        #expect(result!.tableReferences.contains(where: { $0.table == "users" && $0.operation == "delete" }))
    }

    // MARK: - Dialect Mapping

    @Test("Dialect maps to correct parser database name",
          arguments: [
              (EchoSenseDatabaseType.postgresql, "PostgreSQL"),
              (EchoSenseDatabaseType.mysql, "MySQL"),
              (EchoSenseDatabaseType.sqlite, "SQLite"),
              (EchoSenseDatabaseType.microsoftSQL, "TransactSQL"),
          ])
    func dialectMapping(dialect: EchoSenseDatabaseType, expected: String) {
        #expect(dialect.sqlParserDatabase == expected)
    }

    // MARK: - Async API

    @Test("Async parse returns same result as sync")
    func asyncParse() async {
        let syncResult = parser.parseSync(sql: "SELECT 1", dialect: .postgresql)
        let asyncResult = await parser.parse(sql: "SELECT 1", dialect: .postgresql)
        #expect(syncResult?.success == asyncResult?.success)
    }
}
