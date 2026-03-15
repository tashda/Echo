import Testing
@testable import Echo

// MARK: - Helpers

private func makeObject(
    name: String = "test",
    schema: String = "dbo",
    type: SchemaObjectInfo.ObjectType = .table,
    triggerAction: String? = nil,
    triggerTable: String? = nil
) -> SchemaObjectInfo {
    SchemaObjectInfo(
        name: name,
        schema: schema,
        type: type,
        columns: [],
        parameters: [],
        triggerAction: triggerAction,
        triggerTable: triggerTable,
        comment: nil
    )
}

// MARK: - MSSQLScriptProvider

@Suite("MSSQLScriptProvider")
struct MSSQLScriptProviderAllTests {
    let provider = MSSQLScriptProvider()

    // MARK: quoteIdentifier

    @Test func quoteIdentifierSimpleName() {
        #expect(provider.quoteIdentifier("users") == "[users]")
    }

    @Test func quoteIdentifierWithBrackets() {
        #expect(provider.quoteIdentifier("my]table") == "[my]]table]")
    }

    @Test func quoteIdentifierReservedWord() {
        #expect(provider.quoteIdentifier("SELECT") == "[SELECT]")
    }

    @Test func quoteIdentifierTrimsWhitespace() {
        #expect(provider.quoteIdentifier("  name  ") == "[name]")
    }

    @Test func quoteIdentifierDoubleBrackets() {
        #expect(provider.quoteIdentifier("a]]b") == "[a]]]]b]")
    }

    // MARK: qualifiedName

    @Test func qualifiedNameWithSchema() {
        #expect(provider.qualifiedName(schema: "dbo", name: "orders") == "[dbo].[orders]")
    }

    @Test func qualifiedNameWithoutSchema() {
        #expect(provider.qualifiedName(schema: "", name: "orders") == "[orders]")
    }

    @Test func qualifiedNameWhitespaceOnlySchema() {
        #expect(provider.qualifiedName(schema: "   ", name: "orders") == "[orders]")
    }

    // MARK: scriptActions

    @Test func scriptActionsForTable() {
        let ids = provider.scriptActions(for: .table).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("alter"))
        #expect(ids.contains("dropIfExists"))
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
        #expect(!ids.contains("execute"))
        #expect(!ids.contains("createOrReplace"))
    }

    @Test func scriptActionsForView() {
        let ids = provider.scriptActions(for: .view).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("alter"))
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForMaterializedView() {
        let ids = provider.scriptActions(for: .materializedView).map(\.identifier)
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
    }

    @Test func scriptActionsForProcedure() {
        let ids = provider.scriptActions(for: .procedure).map(\.identifier)
        #expect(ids.contains("execute"))
        #expect(!ids.contains("select"))
    }

    @Test func scriptActionsForFunction() {
        let ids = provider.scriptActions(for: .function).map(\.identifier)
        #expect(ids.contains("execute"))
        #expect(!ids.contains("select"))
    }

    @Test func scriptActionsForTrigger() {
        let ids = provider.scriptActions(for: .trigger).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("alter"))
        #expect(ids.contains("dropIfExists"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForExtension() {
        let ids = provider.scriptActions(for: .extension).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    // MARK: executeStatement

    @Test func executeStatementForProcedure() {
        let result = provider.executeStatement(for: .procedure, qualifiedName: "[dbo].[sp_test]")
        #expect(result == "EXEC [dbo].[sp_test] /* arguments */;")
    }

    @Test func executeStatementForFunction() {
        let result = provider.executeStatement(for: .function, qualifiedName: "[dbo].[fn_calc]")
        #expect(result == "SELECT * FROM [dbo].[fn_calc](/* arguments */);")
    }

    @Test func executeStatementForTable() {
        // Tables use the else branch (EXEC)
        let result = provider.executeStatement(for: .table, qualifiedName: "[dbo].[users]")
        #expect(result.contains("EXEC"))
    }

    // MARK: truncateStatement

    @Test func truncateStatement() {
        #expect(provider.truncateStatement(qualifiedName: "[dbo].[users]") == "TRUNCATE TABLE [dbo].[users];")
    }

    // MARK: renameStatement

    @Test func renameStatementWithNewName() {
        let obj = makeObject(name: "old_table", schema: "dbo", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "[dbo].[old_table]", newName: "new_table")
        #expect(result == "EXEC sp_rename 'dbo.old_table', 'new_table';")
    }

    @Test func renameStatementNilName() {
        let obj = makeObject(name: "tbl", schema: "dbo", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "[dbo].[tbl]", newName: nil)
        #expect(result?.contains("<new_name>") == true)
    }

    @Test func renameStatementEmptyName() {
        let obj = makeObject(name: "tbl", schema: "dbo", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "[dbo].[tbl]", newName: "")
        #expect(result?.contains("<new_name>") == true)
    }

    @Test func renameStatementEscapesSingleQuotes() {
        let obj = makeObject(name: "old", schema: "dbo", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "[dbo].[old]", newName: "it's")
        #expect(result?.contains("'it''s'") == true)
    }

    @Test func renameStatementForColumn() {
        // MSSQL uses sp_rename for all object types uniformly
        let obj = makeObject(name: "idx1", schema: "dbo", type: .function)
        let result = provider.renameStatement(for: obj, qualifiedName: "[dbo].[idx1]", newName: "idx2")
        #expect(result?.contains("sp_rename") == true)
    }

    @Test func renameStatementNoSchema() {
        let obj = makeObject(name: "tbl", schema: "", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "[tbl]", newName: "tbl2")
        #expect(result == "EXEC sp_rename 'tbl', 'tbl2';")
    }

    // MARK: dropStatement

    @Test func dropTableWithIfExists() {
        let obj = makeObject(name: "users", schema: "dbo", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[users]", keyword: "TABLE", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP TABLE IF EXISTS [dbo].[users];")
    }

    @Test func dropTableWithoutIfExists() {
        let obj = makeObject(name: "users", schema: "dbo", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[users]", keyword: "TABLE", includeIfExists: false, triggerTargetName: "")
        #expect(result == "DROP TABLE [dbo].[users];")
    }

    @Test func dropView() {
        let obj = makeObject(name: "v_report", schema: "dbo", type: .view)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[v_report]", keyword: "VIEW", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP VIEW IF EXISTS [dbo].[v_report];")
    }

    @Test func dropProcedure() {
        let obj = makeObject(name: "sp_run", schema: "dbo", type: .procedure)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[sp_run]", keyword: "PROCEDURE", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP PROCEDURE IF EXISTS [dbo].[sp_run];")
    }

    @Test func dropFunction() {
        let obj = makeObject(name: "fn_calc", schema: "dbo", type: .function)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[fn_calc]", keyword: "FUNCTION", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP FUNCTION IF EXISTS [dbo].[fn_calc];")
    }

    @Test func dropTriggerIncludesTarget() {
        let obj = makeObject(name: "trg_audit", schema: "dbo", type: .trigger, triggerAction: "INSERT", triggerTable: "users")
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[trg_audit]", keyword: "TRIGGER", includeIfExists: true, triggerTargetName: "[dbo].[users]")
        #expect(result == "DROP TRIGGER IF EXISTS [dbo].[trg_audit] ON [dbo].[users];")
    }

    @Test func dropTriggerWithoutIfExists() {
        let obj = makeObject(name: "trg", schema: "dbo", type: .trigger)
        let result = provider.dropStatement(for: obj, qualifiedName: "[dbo].[trg]", keyword: "TRIGGER", includeIfExists: false, triggerTargetName: "[dbo].[orders]")
        #expect(result == "DROP TRIGGER [dbo].[trg] ON [dbo].[orders];")
    }

    // MARK: alterStatement

    @Test func alterStatementForProcedure() {
        let obj = makeObject(name: "sp_run", schema: "dbo", type: .procedure)
        let result = provider.alterStatement(for: obj, qualifiedName: "[dbo].[sp_run]", keyword: "PROCEDURE")
        #expect(result.contains("ALTER PROCEDURE [dbo].[sp_run]"))
        #expect(result.contains("GO"))
    }

    @Test func alterStatementForView() {
        let obj = makeObject(name: "v_rep", schema: "dbo", type: .view)
        let result = provider.alterStatement(for: obj, qualifiedName: "[dbo].[v_rep]", keyword: "VIEW")
        #expect(result.contains("ALTER VIEW [dbo].[v_rep]"))
    }

    @Test func alterStatementForFunction() {
        let obj = makeObject(name: "fn", schema: "dbo", type: .function)
        let result = provider.alterStatement(for: obj, qualifiedName: "[dbo].[fn]", keyword: "FUNCTION")
        #expect(result.contains("ALTER FUNCTION [dbo].[fn]"))
    }

    // MARK: alterTableStatement

    @Test func alterTableStatement() {
        let result = provider.alterTableStatement(qualifiedName: "[dbo].[users]")
        #expect(result.contains("ALTER TABLE [dbo].[users]"))
        #expect(result.contains("ADD new_column_name data_type"))
    }

    // MARK: selectStatement

    @Test func selectWithColumns() {
        let result = provider.selectStatement(qualifiedName: "[dbo].[users]", columnLines: "[id],\n    [name]", limit: nil, offset: 0)
        #expect(result.contains("SELECT"))
        #expect(result.contains("[id],"))
        #expect(result.contains("[name]"))
        #expect(result.contains("FROM [dbo].[users]"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimit() {
        let result = provider.selectStatement(qualifiedName: "[dbo].[t]", columnLines: "*", limit: 100, offset: 0)
        #expect(result.contains("ORDER BY (SELECT NULL)"))
        #expect(result.contains("OFFSET 0 ROWS"))
        #expect(result.contains("FETCH NEXT 100 ROWS ONLY"))
    }

    @Test func selectWithLimitAndOffset() {
        let result = provider.selectStatement(qualifiedName: "[dbo].[t]", columnLines: "*", limit: 50, offset: 200)
        #expect(result.contains("OFFSET 200 ROWS"))
        #expect(result.contains("FETCH NEXT 50 ROWS ONLY"))
    }

    @Test func selectWithoutLimitNoOffset() {
        let result = provider.selectStatement(qualifiedName: "[dbo].[t]", columnLines: "*", limit: nil, offset: 0)
        #expect(!result.contains("OFFSET"))
        #expect(!result.contains("FETCH"))
        #expect(result.hasSuffix(";"))
    }

    // MARK: supportsTruncateTable

    @Test func supportsTruncateTableIsTrue() {
        #expect(provider.supportsTruncateTable == true)
    }

    // MARK: renameMenuLabel

    @Test func renameMenuLabelIsRename() {
        #expect(provider.renameMenuLabel == "Rename")
    }
}

// MARK: - PostgresScriptProvider

@Suite("PostgresScriptProvider")
struct PostgresScriptProviderTests {
    let provider = PostgresScriptProvider()

    // MARK: quoteIdentifier

    @Test func quoteIdentifierSimple() {
        #expect(provider.quoteIdentifier("users") == "\"users\"")
    }

    @Test func quoteIdentifierWithDoubleQuotes() {
        #expect(provider.quoteIdentifier("my\"table") == "\"my\"\"table\"")
    }

    @Test func quoteIdentifierReservedWord() {
        #expect(provider.quoteIdentifier("select") == "\"select\"")
    }

    @Test func quoteIdentifierTrimsWhitespace() {
        #expect(provider.quoteIdentifier("  name  ") == "\"name\"")
    }

    // MARK: qualifiedName

    @Test func qualifiedNameWithSchema() {
        #expect(provider.qualifiedName(schema: "public", name: "users") == "\"public\".\"users\"")
    }

    @Test func qualifiedNameWithoutSchema() {
        #expect(provider.qualifiedName(schema: "", name: "users") == "\"users\"")
    }

    @Test func qualifiedNameWhitespaceSchema() {
        #expect(provider.qualifiedName(schema: "   ", name: "users") == "\"users\"")
    }

    // MARK: scriptActions

    @Test func scriptActionsForTable() {
        let ids = provider.scriptActions(for: .table).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(!ids.contains("createOrReplace")) // tables don't get CREATE OR REPLACE
        #expect(ids.contains("dropIfExists"))
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForView() {
        let ids = provider.scriptActions(for: .view).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
    }

    @Test func scriptActionsForMaterializedView() {
        let ids = provider.scriptActions(for: .materializedView).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(ids.contains("select"))
    }

    @Test func scriptActionsForProcedure() {
        let ids = provider.scriptActions(for: .procedure).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(ids.contains("execute"))
        #expect(ids.contains("select"))
    }

    @Test func scriptActionsForFunction() {
        let ids = provider.scriptActions(for: .function).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(ids.contains("execute"))
        #expect(ids.contains("select"))
    }

    @Test func scriptActionsForTrigger() {
        let ids = provider.scriptActions(for: .trigger).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(ids.contains("dropIfExists"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForExtension() {
        let ids = provider.scriptActions(for: .extension).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("createOrReplace"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    // MARK: executeStatement

    @Test func executeStatementForProcedure() {
        let result = provider.executeStatement(for: .procedure, qualifiedName: "\"public\".\"my_proc\"")
        #expect(result == "CALL \"public\".\"my_proc\"(/* arguments */);")
    }

    @Test func executeStatementForFunction() {
        let result = provider.executeStatement(for: .function, qualifiedName: "\"public\".\"my_func\"")
        #expect(result == "SELECT * FROM \"public\".\"my_func\"(/* arguments */);")
    }

    @Test func executeStatementForTable() {
        // Non-procedure uses SELECT form
        let result = provider.executeStatement(for: .table, qualifiedName: "\"public\".\"t\"")
        #expect(result.contains("SELECT * FROM"))
    }

    // MARK: truncateStatement

    @Test func truncateStatement() {
        #expect(provider.truncateStatement(qualifiedName: "\"public\".\"users\"") == "TRUNCATE TABLE \"public\".\"users\";")
    }

    // MARK: renameStatement

    @Test func renameTable() {
        let obj = makeObject(name: "old_tbl", schema: "public", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"old_tbl\"", newName: "new_tbl")
        #expect(result == "ALTER TABLE \"public\".\"old_tbl\" RENAME TO \"new_tbl\";")
    }

    @Test func renameView() {
        let obj = makeObject(name: "v1", schema: "public", type: .view)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"v1\"", newName: "v2")
        #expect(result == "ALTER VIEW \"public\".\"v1\" RENAME TO \"v2\";")
    }

    @Test func renameMaterializedView() {
        let obj = makeObject(name: "mv1", schema: "public", type: .materializedView)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"mv1\"", newName: "mv2")
        #expect(result == "ALTER MATERIALIZED VIEW \"public\".\"mv1\" RENAME TO \"mv2\";")
    }

    @Test func renameFunctionNilNameReturnsTemplate() {
        let obj = makeObject(name: "fn", schema: "public", type: .function)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"fn\"", newName: nil)
        #expect(result != nil)
        #expect(result!.contains("ALTER FUNCTION"))
        #expect(result!.contains("/* arg_types */"))
        #expect(result!.contains("<new_name>"))
    }

    @Test func renameFunctionWithNameReturnsNil() {
        let obj = makeObject(name: "fn", schema: "public", type: .function)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"fn\"", newName: "fn2")
        #expect(result == nil)
    }

    @Test func renameProcedureNilNameReturnsTemplate() {
        let obj = makeObject(name: "proc", schema: "public", type: .procedure)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"proc\"", newName: nil)
        #expect(result != nil)
        #expect(result!.contains("ALTER PROCEDURE"))
    }

    @Test func renameProcedureWithNameReturnsNil() {
        let obj = makeObject(name: "proc", schema: "public", type: .procedure)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"proc\"", newName: "proc2")
        #expect(result == nil)
    }

    @Test func renameTrigger() {
        let obj = makeObject(name: "trg1", schema: "public", type: .trigger, triggerTable: "orders")
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"trg1\"", newName: "trg2")
        #expect(result != nil)
        #expect(result!.contains("ALTER TRIGGER"))
        #expect(result!.contains("RENAME TO \"trg2\""))
        #expect(result!.contains("ON \"public\".\"orders\""))
    }

    @Test func renameTriggerNoTriggerTable() {
        let obj = makeObject(name: "trg1", schema: "public", type: .trigger)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"trg1\"", newName: "trg2")
        #expect(result != nil)
        #expect(result!.contains("<table_name>"))
    }

    @Test func renameExtensionReturnsNil() {
        let obj = makeObject(name: "ext", schema: "public", type: .extension)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"ext\"", newName: "ext2")
        #expect(result == nil)
    }

    @Test func renameTableNilName() {
        let obj = makeObject(name: "tbl", schema: "public", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"tbl\"", newName: nil)
        #expect(result?.contains("<new_name>") == true)
    }

    @Test func renameTableEmptyName() {
        let obj = makeObject(name: "tbl", schema: "public", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"public\".\"tbl\"", newName: "")
        #expect(result?.contains("<new_name>") == true)
    }

    // MARK: dropStatement

    @Test func dropTableWithIfExists() {
        let obj = makeObject(name: "users", schema: "public", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"users\"", keyword: "TABLE", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP TABLE IF EXISTS \"public\".\"users\";")
    }

    @Test func dropTableWithoutIfExists() {
        let obj = makeObject(name: "users", schema: "public", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"users\"", keyword: "TABLE", includeIfExists: false, triggerTargetName: "")
        #expect(result == "DROP TABLE \"public\".\"users\";")
    }

    @Test func dropView() {
        let obj = makeObject(name: "v1", schema: "public", type: .view)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"v1\"", keyword: "VIEW", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP VIEW IF EXISTS \"public\".\"v1\";")
    }

    @Test func dropTriggerIncludesTarget() {
        let obj = makeObject(name: "trg", schema: "public", type: .trigger, triggerTable: "orders")
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"trg\"", keyword: "TRIGGER", includeIfExists: true, triggerTargetName: "\"public\".\"orders\"")
        #expect(result == "DROP TRIGGER IF EXISTS \"trg\" ON \"public\".\"orders\";")
    }

    @Test func dropFunctionIncludesArgTypes() {
        let obj = makeObject(name: "fn", schema: "public", type: .function)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"fn\"", keyword: "FUNCTION", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP FUNCTION IF EXISTS \"public\".\"fn\"(/* arg_types */);")
    }

    @Test func dropProcedureIncludesArgTypes() {
        let obj = makeObject(name: "proc", schema: "public", type: .procedure)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"public\".\"proc\"", keyword: "PROCEDURE", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP FUNCTION IF EXISTS \"public\".\"proc\"(/* arg_types */);")
    }

    // MARK: alterStatement

    @Test func alterStatementReturnsComment() {
        let obj = makeObject(name: "v1", schema: "public", type: .view)
        let result = provider.alterStatement(for: obj, qualifiedName: "\"public\".\"v1\"", keyword: "VIEW")
        #expect(result.contains("ALTER is not directly supported"))
        #expect(result.contains("CREATE OR REPLACE"))
    }

    // MARK: alterTableStatement

    @Test func alterTableStatement() {
        let result = provider.alterTableStatement(qualifiedName: "\"public\".\"users\"")
        #expect(result.contains("ALTER TABLE \"public\".\"users\""))
        #expect(result.contains("ADD COLUMN new_column_name data_type"))
    }

    // MARK: selectStatement

    @Test func selectWithoutLimit() {
        let result = provider.selectStatement(qualifiedName: "\"public\".\"users\"", columnLines: "\"id\",\n    \"name\"", limit: nil, offset: 0)
        #expect(result.contains("SELECT"))
        #expect(result.contains("FROM \"public\".\"users\""))
        #expect(!result.contains("LIMIT"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimit() {
        let result = provider.selectStatement(qualifiedName: "\"public\".\"t\"", columnLines: "*", limit: 100, offset: 0)
        #expect(result.contains("LIMIT 100"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimitAndOffset() {
        let result = provider.selectStatement(qualifiedName: "\"public\".\"t\"", columnLines: "*", limit: 50, offset: 10)
        #expect(result.contains("LIMIT 50"))
        #expect(result.contains("OFFSET 10"))
    }

    @Test func selectWithOffsetOnly() {
        let result = provider.selectStatement(qualifiedName: "\"public\".\"t\"", columnLines: "*", limit: nil, offset: 25)
        #expect(!result.contains("LIMIT"))
        #expect(result.contains("OFFSET 25"))
    }

    @Test func selectEndsWithSemicolon() {
        let result = provider.selectStatement(qualifiedName: "\"t\"", columnLines: "*", limit: 10, offset: 0)
        #expect(result.hasSuffix(";"))
    }

    // MARK: supportsTruncateTable

    @Test func supportsTruncateTableIsTrue() {
        #expect(provider.supportsTruncateTable == true)
    }

    // MARK: renameMenuLabel

    @Test func renameMenuLabelIsRename() {
        #expect(provider.renameMenuLabel == "Rename")
    }
}

// MARK: - SQLiteScriptProvider

@Suite("SQLiteScriptProvider")
struct SQLiteScriptProviderTests {
    let provider = SQLiteScriptProvider()

    // MARK: quoteIdentifier

    @Test func quoteIdentifierSimple() {
        #expect(provider.quoteIdentifier("users") == "\"users\"")
    }

    @Test func quoteIdentifierWithDoubleQuotes() {
        #expect(provider.quoteIdentifier("my\"table") == "\"my\"\"table\"")
    }

    @Test func quoteIdentifierTrimsWhitespace() {
        #expect(provider.quoteIdentifier("  name  ") == "\"name\"")
    }

    // MARK: qualifiedName (ignores schema)

    @Test func qualifiedNameIgnoresSchema() {
        #expect(provider.qualifiedName(schema: "main", name: "users") == "\"users\"")
    }

    @Test func qualifiedNameEmptySchema() {
        #expect(provider.qualifiedName(schema: "", name: "users") == "\"users\"")
    }

    @Test func qualifiedNameAlwaysReturnsJustName() {
        #expect(provider.qualifiedName(schema: "some_schema", name: "tbl") == "\"tbl\"")
    }

    // MARK: scriptActions

    @Test func scriptActionsForTable() {
        let ids = provider.scriptActions(for: .table).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("drop"))
        #expect(ids.contains("select"))
        #expect(ids.contains("selectLimited_1000"))
        #expect(!ids.contains("alter"))
        #expect(!ids.contains("createOrReplace"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForView() {
        let ids = provider.scriptActions(for: .view).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("drop"))
        #expect(ids.contains("select"))
        #expect(!ids.contains("alter"))
    }

    @Test func scriptActionsForFunction() {
        let ids = provider.scriptActions(for: .function).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("drop"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForTrigger() {
        let ids = provider.scriptActions(for: .trigger).map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("drop"))
        #expect(!ids.contains("select"))
    }

    @Test func scriptActionsForProcedure() {
        let ids = provider.scriptActions(for: .procedure).map(\.identifier)
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    // MARK: executeStatement

    @Test func executeStatementNotSupported() {
        let result = provider.executeStatement(for: .function, qualifiedName: "\"fn\"")
        #expect(result.contains("not supported"))
    }

    @Test func executeStatementForProcedureNotSupported() {
        let result = provider.executeStatement(for: .procedure, qualifiedName: "\"proc\"")
        #expect(result.contains("not supported"))
    }

    // MARK: truncateStatement

    @Test func truncateStatementNotSupported() {
        let result = provider.truncateStatement(qualifiedName: "\"users\"")
        #expect(result.contains("not supported"))
    }

    // MARK: renameStatement

    @Test func renameTable() {
        let obj = makeObject(name: "old", schema: "main", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"old\"", newName: "new")
        #expect(result == "ALTER TABLE \"old\" RENAME TO \"new\";")
    }

    @Test func renameTableNilName() {
        let obj = makeObject(name: "tbl", schema: "main", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"tbl\"", newName: nil)
        #expect(result?.contains("<new_name>") == true)
    }

    @Test func renameTableEmptyName() {
        let obj = makeObject(name: "tbl", schema: "main", type: .table)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"tbl\"", newName: "")
        #expect(result?.contains("<new_name>") == true)
    }

    @Test func renameViewReturnsComment() {
        let obj = makeObject(name: "v1", schema: "main", type: .view)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"v1\"", newName: "v2")
        #expect(result != nil)
        #expect(result!.contains("cannot rename views"))
    }

    @Test func renameTriggerNotSupported() {
        let obj = makeObject(name: "trg", schema: "main", type: .trigger)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"trg\"", newName: "trg2")
        #expect(result != nil)
        #expect(result!.contains("not supported"))
    }

    @Test func renameFunctionNotSupported() {
        let obj = makeObject(name: "fn", schema: "main", type: .function)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"fn\"", newName: "fn2")
        #expect(result != nil)
        #expect(result!.contains("not supported"))
    }

    @Test func renameProcedureNotSupported() {
        let obj = makeObject(name: "proc", schema: "main", type: .procedure)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"proc\"", newName: "proc2")
        #expect(result != nil)
        #expect(result!.contains("not supported"))
    }

    @Test func renameMaterializedViewNotSupported() {
        let obj = makeObject(name: "mv", schema: "main", type: .materializedView)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"mv\"", newName: "mv2")
        #expect(result != nil)
        #expect(result!.contains("not supported"))
    }

    @Test func renameExtensionNotSupported() {
        let obj = makeObject(name: "ext", schema: "main", type: .extension)
        let result = provider.renameStatement(for: obj, qualifiedName: "\"ext\"", newName: "ext2")
        #expect(result != nil)
        #expect(result!.contains("not supported"))
    }

    // MARK: dropStatement

    @Test func dropTableWithIfExists() {
        let obj = makeObject(name: "users", schema: "main", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"users\"", keyword: "TABLE", includeIfExists: true, triggerTargetName: "")
        #expect(result == "DROP TABLE IF EXISTS \"users\";")
    }

    @Test func dropTableWithoutIfExists() {
        let obj = makeObject(name: "users", schema: "main", type: .table)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"users\"", keyword: "TABLE", includeIfExists: false, triggerTargetName: "")
        #expect(result == "DROP TABLE \"users\";")
    }

    @Test func dropTriggerDoesNotIncludeTarget() {
        // SQLite drop trigger does NOT use ON target (unlike MSSQL/Postgres)
        let obj = makeObject(name: "trg", schema: "main", type: .trigger)
        let result = provider.dropStatement(for: obj, qualifiedName: "\"trg\"", keyword: "TRIGGER", includeIfExists: true, triggerTargetName: "\"users\"")
        #expect(result == "DROP TRIGGER IF EXISTS \"trg\";")
    }

    // MARK: alterStatement

    @Test func alterStatementReturnsComment() {
        let obj = makeObject(name: "v1", schema: "main", type: .view)
        let result = provider.alterStatement(for: obj, qualifiedName: "\"v1\"", keyword: "VIEW")
        #expect(result.contains("ALTER is not directly supported"))
    }

    // MARK: alterTableStatement

    @Test func alterTableStatement() {
        let result = provider.alterTableStatement(qualifiedName: "\"users\"")
        #expect(result.contains("ALTER TABLE \"users\""))
        #expect(result.contains("RENAME COLUMN old_column TO new_column"))
    }

    // MARK: selectStatement

    @Test func selectWithoutLimit() {
        let result = provider.selectStatement(qualifiedName: "\"users\"", columnLines: "\"id\"", limit: nil, offset: 0)
        #expect(result.contains("SELECT"))
        #expect(result.contains("FROM \"users\""))
        #expect(!result.contains("LIMIT"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimit() {
        let result = provider.selectStatement(qualifiedName: "\"t\"", columnLines: "*", limit: 100, offset: 0)
        #expect(result.contains("LIMIT 100"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimitAndOffset() {
        let result = provider.selectStatement(qualifiedName: "\"t\"", columnLines: "*", limit: 50, offset: 10)
        #expect(result.contains("LIMIT 50"))
        #expect(result.contains("OFFSET 10"))
    }

    @Test func selectWithOffsetOnly() {
        let result = provider.selectStatement(qualifiedName: "\"t\"", columnLines: "*", limit: nil, offset: 25)
        #expect(result.contains("OFFSET 25"))
        #expect(!result.contains("LIMIT"))
    }

    // MARK: supportsTruncateTable

    @Test func supportsTruncateTableIsFalse() {
        #expect(provider.supportsTruncateTable == false)
    }

    // MARK: renameMenuLabel

    @Test func renameMenuLabelIsLimited() {
        #expect(provider.renameMenuLabel == "Rename (Limited)")
    }
}
