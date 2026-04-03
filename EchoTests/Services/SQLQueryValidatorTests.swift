import Testing
@testable import Echo
import EchoSense

@Suite("SQL Query Validator")
struct SQLQueryValidatorTests {
    private let validator = SQLQueryValidator()

    // MARK: - Test Metadata

    /// Build a simple structure with one database, one schema, and specified tables/columns
    private func makeStructure(
        database: String = "testdb",
        schema: String = "public",
        tables: [String: [String]] = ["users": ["id", "name", "email"], "orders": ["id", "user_id", "total"]]
    ) -> EchoSenseDatabaseStructure {
        let objects = tables.map { tableName, columns in
            EchoSenseSchemaObjectInfo(
                name: tableName,
                schema: schema,
                type: .table,
                columns: columns.map { EchoSenseColumnInfo(name: $0, dataType: "text") }
            )
        }
        return EchoSenseDatabaseStructure(databases: [
            EchoSenseDatabaseInfo(name: database, schemas: [
                EchoSenseSchemaInfo(name: schema, objects: objects)
            ])
        ])
    }

    /// Build a structure with multiple schemas
    private func makeMultiSchemaStructure() -> EchoSenseDatabaseStructure {
        EchoSenseDatabaseStructure(databases: [
            EchoSenseDatabaseInfo(name: "testdb", schemas: [
                EchoSenseSchemaInfo(name: "public", objects: [
                    EchoSenseSchemaObjectInfo(name: "users", schema: "public", type: .table, columns: [
                        EchoSenseColumnInfo(name: "id", dataType: "int"),
                        EchoSenseColumnInfo(name: "name", dataType: "text"),
                    ]),
                ]),
                EchoSenseSchemaInfo(name: "auth", objects: [
                    EchoSenseSchemaObjectInfo(name: "sessions", schema: "auth", type: .table, columns: [
                        EchoSenseColumnInfo(name: "id", dataType: "int"),
                        EchoSenseColumnInfo(name: "token", dataType: "text"),
                    ]),
                ]),
            ])
        ])
    }

    // MARK: - Syntax Errors

    @Test("Syntax error returns diagnostic for complete-looking bad SQL")
    func syntaxError() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FORM users WHERE id = 1",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.kind == .syntaxError)
        #expect(diagnostics.first?.confidence == .high)
    }

    @Test("Incomplete statement is not flagged")
    func incompleteStatement() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.isEmpty)
    }

    // MARK: - Unknown Table

    @Test("Unknown table after FROM")
    func unknownTable() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM nonexistent",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownTable && $0.token == "nonexistent" }))
    }

    @Test("Known table produces no diagnostic")
    func knownTable() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM users",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.isEmpty)
    }

    @Test("Known table in JOIN produces no diagnostic")
    func knownTableJoin() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.isEmpty)
    }

    @Test("Unknown table in JOIN is flagged")
    func unknownTableJoin() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM users u JOIN nonexistent n ON u.id = n.user_id",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownTable && $0.token == "nonexistent" }))
    }

    // MARK: - Unknown Schema

    @Test("Unknown schema is flagged")
    func unknownSchema() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM bad_schema.users",
            structure: makeMultiSchemaStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownSchema && $0.token == "bad_schema" }))
    }

    @Test("Known schema produces no diagnostic")
    func knownSchema() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM auth.sessions",
            structure: makeMultiSchemaStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.isEmpty)
    }

    @Test("Unknown table in known schema is flagged")
    func unknownTableInKnownSchema() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM auth.nonexistent",
            structure: makeMultiSchemaStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownTable && $0.token == "nonexistent" }))
    }

    // MARK: - Unknown Column

    @Test("Unknown column is flagged when all tables resolved")
    func unknownColumn() async {
        let diagnostics = await validator.validate(
            sql: "SELECT bad_col FROM users",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownColumn && $0.token == "bad_col" }))
    }

    @Test("Known column produces no diagnostic")
    func knownColumn() async {
        let diagnostics = await validator.validate(
            sql: "SELECT id, name FROM users",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(!diagnostics.contains(where: { $0.kind == .unknownColumn }))
    }

    @Test("Column from joined table produces no diagnostic")
    func columnFromJoinedTable() async {
        let diagnostics = await validator.validate(
            sql: "SELECT user_id, total FROM users JOIN orders ON users.id = orders.user_id",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(!diagnostics.contains(where: { $0.kind == .unknownColumn }))
    }

    @Test("Unknown column suppressed when a table in scope is unresolved")
    func unknownColumnSuppressedWhenTableUnresolved() async {
        let diagnostics = await validator.validate(
            sql: "SELECT mystery_col FROM users JOIN unknown_table ON true",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        // unknownTable for unknown_table should be flagged
        #expect(diagnostics.contains(where: { $0.kind == .unknownTable && $0.token == "unknown_table" }))
        // But unknownColumn should be suppressed (medium confidence, filtered out)
        #expect(!diagnostics.contains(where: { $0.kind == .unknownColumn }))
    }

    // MARK: - Metadata Safety

    @Test("No diagnostics when structure is nil")
    func noStructure() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM nonexistent",
            structure: nil,
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        // Only syntax checks run — this SQL is syntactically valid
        #expect(diagnostics.isEmpty)
    }

    @Test("Cross-database: validates against all databases in structure")
    func crossDatabase() async {
        // Even with selectedDatabase nil, tables from any database should be recognized
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM users",
            structure: makeStructure(),
            selectedDatabase: nil,
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.isEmpty) // users exists in the structure
    }

    @Test("Cross-database: unknown table flagged across all databases")
    func crossDatabaseUnknown() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM nonexistent",
            structure: makeStructure(),
            selectedDatabase: nil,
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(diagnostics.contains(where: { $0.kind == .unknownTable && $0.token == "nonexistent" }))
    }

    // MARK: - Star Column

    @Test("SELECT * does not flag unknown columns")
    func selectStar() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM users",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .postgresql
        )
        #expect(!diagnostics.contains(where: { $0.kind == .unknownColumn }))
    }

    // MARK: - Dialect Tests

    @Test("MSSQL schema.table works (dbo)")
    func mssqlDboSchema() async {
        let structure = makeStructure(schema: "dbo")
        let diagnostics = await validator.validate(
            sql: "SELECT TOP 10 * FROM dbo.users",
            structure: structure,
            selectedDatabase: "testdb",
            defaultSchema: "dbo",
            dialect: .microsoftSQL
        )
        #expect(diagnostics.isEmpty)
    }

    @Test("MySQL validates tables")
    func mysqlValidation() async {
        let diagnostics = await validator.validate(
            sql: "SELECT * FROM `users` LIMIT 10",
            structure: makeStructure(),
            selectedDatabase: "testdb",
            defaultSchema: "public",
            dialect: .mysql
        )
        #expect(diagnostics.isEmpty)
    }
}
