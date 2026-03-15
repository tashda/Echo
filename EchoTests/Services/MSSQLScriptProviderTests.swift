import Testing
@testable import Echo

@Suite("MSSQLScriptProvider")
struct MSSQLScriptProviderTests {
    let provider = MSSQLScriptProvider()

    // MARK: - Identifier Quoting

    @Test func quoteSimpleIdentifier() {
        #expect(provider.quoteIdentifier("users") == "[users]")
    }

    @Test func quoteIdentifierWithBrackets() {
        #expect(provider.quoteIdentifier("my]table") == "[my]]table]")
    }

    @Test func quoteIdentifierTrimsWhitespace() {
        #expect(provider.quoteIdentifier("  users  ") == "[users]")
    }

    // MARK: - Qualified Name

    @Test func qualifiedNameWithSchema() {
        #expect(provider.qualifiedName(schema: "dbo", name: "users") == "[dbo].[users]")
    }

    @Test func qualifiedNameWithoutSchema() {
        #expect(provider.qualifiedName(schema: "", name: "users") == "[users]")
    }

    @Test func qualifiedNameTrimsSchemaWhitespace() {
        #expect(provider.qualifiedName(schema: "  ", name: "users") == "[users]")
    }

    // MARK: - Script Actions

    @Test func scriptActionsForTable() {
        let actions = provider.scriptActions(for: .table)
        let ids = actions.map(\.identifier)
        #expect(ids.contains("create"))
        #expect(ids.contains("alter"))
        #expect(ids.contains("dropIfExists"))
        #expect(ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    @Test func scriptActionsForProcedure() {
        let actions = provider.scriptActions(for: .procedure)
        let ids = actions.map(\.identifier)
        #expect(ids.contains("execute"))
        #expect(!ids.contains("select"))
    }

    @Test func scriptActionsForFunction() {
        let actions = provider.scriptActions(for: .function)
        let ids = actions.map(\.identifier)
        #expect(ids.contains("execute"))
    }

    @Test func scriptActionsForTrigger() {
        let actions = provider.scriptActions(for: .trigger)
        let ids = actions.map(\.identifier)
        #expect(ids.contains("create"))
        #expect(!ids.contains("select"))
        #expect(!ids.contains("execute"))
    }

    // MARK: - Execute Statement

    @Test func executeFunction() {
        let result = provider.executeStatement(for: .function, qualifiedName: "[dbo].[fn_calc]")
        #expect(result == "SELECT * FROM [dbo].[fn_calc](/* arguments */);")
    }

    @Test func executeProcedure() {
        let result = provider.executeStatement(for: .procedure, qualifiedName: "[dbo].[sp_run]")
        #expect(result == "EXEC [dbo].[sp_run] /* arguments */;")
    }

    // MARK: - Truncate

    @Test func truncateStatement() {
        let result = provider.truncateStatement(qualifiedName: "[dbo].[users]")
        #expect(result == "TRUNCATE TABLE [dbo].[users];")
    }

    @Test func supportsTruncate() {
        #expect(provider.supportsTruncateTable)
    }

    // MARK: - Rename

    @Test func renameStatementWithNewName() {
        let object = SchemaObjectInfo(
            name: "old_table",
            schema: "dbo",
            type: .table,
            columns: [],
            parameters: [],
            triggerAction: nil,
            triggerTable: nil,
            comment: nil
        )
        let result = provider.renameStatement(for: object, qualifiedName: "[dbo].[old_table]", newName: "new_table")
        #expect(result == "EXEC sp_rename 'dbo.old_table', 'new_table';")
    }

    @Test func renameStatementEscapesSingleQuotes() {
        let object = SchemaObjectInfo(
            name: "old", schema: "dbo", type: .table,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let result = provider.renameStatement(for: object, qualifiedName: "[dbo].[old]", newName: "it's")
        #expect(result?.contains("'it''s'") == true)
    }

    @Test func renameStatementNilName() {
        let object = SchemaObjectInfo(
            name: "tbl", schema: "dbo", type: .table,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let result = provider.renameStatement(for: object, qualifiedName: "[dbo].[tbl]", newName: nil)
        #expect(result?.contains("<new_name>") == true)
    }

    // MARK: - Drop

    @Test func dropWithIfExists() {
        let object = SchemaObjectInfo(
            name: "users", schema: "dbo", type: .table,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let result = provider.dropStatement(
            for: object, qualifiedName: "[dbo].[users]",
            keyword: "TABLE", includeIfExists: true, triggerTargetName: ""
        )
        #expect(result == "DROP TABLE IF EXISTS [dbo].[users];")
    }

    @Test func dropWithoutIfExists() {
        let object = SchemaObjectInfo(
            name: "users", schema: "dbo", type: .table,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let result = provider.dropStatement(
            for: object, qualifiedName: "[dbo].[users]",
            keyword: "TABLE", includeIfExists: false, triggerTargetName: ""
        )
        #expect(result == "DROP TABLE [dbo].[users];")
    }

    @Test func dropTriggerIncludesTarget() {
        let object = SchemaObjectInfo(
            name: "trg_audit", schema: "dbo", type: .trigger,
            columns: [], parameters: [],
            triggerAction: "INSERT", triggerTable: "users", comment: nil
        )
        let result = provider.dropStatement(
            for: object, qualifiedName: "[dbo].[trg_audit]",
            keyword: "TRIGGER", includeIfExists: true,
            triggerTargetName: "[dbo].[users]"
        )
        #expect(result == "DROP TRIGGER IF EXISTS [dbo].[trg_audit] ON [dbo].[users];")
    }

    // MARK: - Alter

    @Test func alterStatement() {
        let object = SchemaObjectInfo(
            name: "sp_run", schema: "dbo", type: .procedure,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let result = provider.alterStatement(for: object, qualifiedName: "[dbo].[sp_run]", keyword: "PROCEDURE")
        #expect(result.contains("ALTER PROCEDURE [dbo].[sp_run]"))
        #expect(result.contains("GO"))
    }

    @Test func alterTableStatement() {
        let result = provider.alterTableStatement(qualifiedName: "[dbo].[users]")
        #expect(result.contains("ALTER TABLE [dbo].[users]"))
        #expect(result.contains("ADD new_column_name data_type"))
    }

    // MARK: - Select

    @Test func selectWithoutLimit() {
        let result = provider.selectStatement(
            qualifiedName: "[dbo].[users]",
            columnLines: "[id],\n    [name]",
            limit: nil,
            offset: 0
        )
        #expect(result.contains("SELECT"))
        #expect(result.contains("[id],"))
        #expect(result.contains("FROM [dbo].[users]"))
        #expect(!result.contains("OFFSET"))
    }

    @Test func selectWithLimit() {
        let result = provider.selectStatement(
            qualifiedName: "[dbo].[users]",
            columnLines: "*",
            limit: 1000,
            offset: 0
        )
        #expect(result.contains("ORDER BY (SELECT NULL)"))
        #expect(result.contains("OFFSET 0 ROWS"))
        #expect(result.contains("FETCH NEXT 1000 ROWS ONLY"))
    }

    @Test func selectWithOffset() {
        let result = provider.selectStatement(
            qualifiedName: "[dbo].[users]",
            columnLines: "*",
            limit: 100,
            offset: 50
        )
        #expect(result.contains("OFFSET 50 ROWS"))
    }

    // MARK: - Protocol Defaults

    @Test func triggerTargetNameFromObject() {
        let object = SchemaObjectInfo(
            name: "trg_audit", schema: "dbo", type: .trigger,
            columns: [], parameters: [],
            triggerAction: "INSERT", triggerTable: "users", comment: nil
        )
        let target = provider.triggerTargetName(for: object)
        #expect(target == "[dbo].[users]")
    }

    @Test func triggerTargetNameWithQualifiedTable() {
        let object = SchemaObjectInfo(
            name: "trg", schema: "dbo", type: .trigger,
            columns: [], parameters: [],
            triggerAction: "INSERT", triggerTable: "sales.orders", comment: nil
        )
        let target = provider.triggerTargetName(for: object)
        #expect(target == "[sales].[orders]")
    }

    @Test func triggerTargetNameMissing() {
        let object = SchemaObjectInfo(
            name: "trg", schema: "dbo", type: .trigger,
            columns: [], parameters: [],
            triggerAction: nil, triggerTable: nil, comment: nil
        )
        let target = provider.triggerTargetName(for: object)
        #expect(target == "[dbo].[<table_name>]")
    }

    @Test func qualifiedForStoredProcedures() {
        let result = provider.qualifiedForStoredProcedures(schema: "dbo", name: "sp_run")
        #expect(result == "dbo.sp_run")
    }

    @Test func qualifiedForStoredProceduresNoSchema() {
        let result = provider.qualifiedForStoredProcedures(schema: "", name: "sp_run")
        #expect(result == "sp_run")
    }

    @Test func renameMenuLabel() {
        #expect(provider.renameMenuLabel == "Rename")
    }
}
