import Testing
@testable import Echo

struct GenerateScriptsScriptBuilderTests {
    @Test
    func mysqlGroupsPreferSelectedObject() {
        let table = GenerateScriptsObject(schema: "sakila", name: "actor", type: .table)
        let view = GenerateScriptsObject(schema: "sakila", name: "actor_info", type: .view)
        let groups = GenerateScriptsScriptBuilder.categoryGroups(for: [view, table])

        #expect(groups.map(\.category) == ["Tables", "Views"])
        #expect(GenerateScriptsScriptBuilder.defaultSelection(from: [table, view], preferredObjectID: view.id) == [view.id])
    }

    @Test
    func mysqlWrapsTableDefinitionWithIfNotExists() {
        let object = GenerateScriptsObject(schema: "sakila", name: "actor", type: .table)
        let script = GenerateScriptsScriptBuilder.wrappedDefinition(
            "CREATE TABLE `sakila`.`actor` (\n  `actor_id` int NOT NULL\n)",
            object: object,
            databaseType: .mysql,
            checkExistence: true,
            scriptDropAndCreate: false
        )

        #expect(script.contains("CREATE TABLE IF NOT EXISTS"))
        #expect(script.hasSuffix(";"))
    }

    @Test
    func mysqlDropAndCreateAddsDropStatement() {
        let object = GenerateScriptsObject(schema: "sakila", name: "actor", type: .table)
        let script = GenerateScriptsScriptBuilder.wrappedDefinition(
            "CREATE TABLE `sakila`.`actor` (\n  `actor_id` int NOT NULL\n)",
            object: object,
            databaseType: .mysql,
            checkExistence: false,
            scriptDropAndCreate: true
        )

        #expect(script.contains("DROP TABLE IF EXISTS `sakila`.`actor`;"))
        #expect(script.contains("CREATE TABLE `sakila`.`actor`"))
    }

    @Test
    func mysqlInsertStatementsQuoteIdentifiers() {
        let result = QueryResultSet(
            columns: [
                ColumnInfo(name: "actor_id", dataType: "int"),
                ColumnInfo(name: "first_name", dataType: "varchar")
            ],
            rows: [["1", "PENELOPE"], ["2", "NICK"]]
        )
        let object = GenerateScriptsObject(schema: "sakila", name: "actor", type: .table)

        let script = GenerateScriptsScriptBuilder.insertStatements(
            for: result,
            object: object,
            databaseType: .mysql
        )

        #expect(script.contains("INSERT INTO `sakila`.`actor` (`actor_id`, `first_name`) VALUES (1, 'PENELOPE');"))
        #expect(script.contains("INSERT INTO `sakila`.`actor` (`actor_id`, `first_name`) VALUES (2, 'NICK');"))
    }
}
