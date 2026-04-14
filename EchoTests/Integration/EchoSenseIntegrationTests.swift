import XCTest
@testable import Echo
import EchoSense

final class EchoSenseIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal EchoSenseDatabaseStructure for autocompletion testing.
    private func makeTestStructure() -> EchoSenseDatabaseStructure {
        let usersTable = EchoSenseSchemaObjectInfo(
            name: "users",
            schema: "public",
            type: .table,
            columns: [
                EchoSenseColumnInfo(name: "id", dataType: "integer", isPrimaryKey: true),
                EchoSenseColumnInfo(name: "name", dataType: "text"),
                EchoSenseColumnInfo(name: "email", dataType: "text"),
            ]
        )

        let ordersTable = EchoSenseSchemaObjectInfo(
            name: "orders",
            schema: "public",
            type: .table,
            columns: [
                EchoSenseColumnInfo(name: "id", dataType: "integer", isPrimaryKey: true),
                EchoSenseColumnInfo(name: "user_id", dataType: "integer"),
                EchoSenseColumnInfo(name: "total", dataType: "decimal"),
            ]
        )

        let schema = EchoSenseSchemaInfo(
            name: "public",
            objects: [usersTable, ordersTable]
        )

        let database = EchoSenseDatabaseInfo(
            name: "testdb",
            schemas: [schema]
        )

        return EchoSenseDatabaseStructure(databases: [database])
    }

    /// Creates an SQLAutoCompletionEngine configured with the test structure.
    private func makeEngine() -> SQLAutoCompletionEngine {
        let engine = SQLAutoCompletionEngine()
        let context = SQLEditorCompletionContext(
            databaseType: .postgresql,
            selectedDatabase: "testdb",
            defaultSchema: "public",
            structure: makeTestStructure()
        )
        engine.updateContext(context)
        return engine
    }

    /// Builds a minimal SQLAutoCompletionQuery suitable for testing.
    ///
    /// The `token` is the partial text at the caret (empty when the caret is
    /// right after a space), and `clause` tells the engine what kind of
    /// completions to produce.
    private func makeQuery(
        token: String = "",
        prefix: String = "",
        clause: SQLClause,
        precedingKeyword: String? = nil,
        focusTable: SQLAutoCompletionTableFocus? = nil,
        tablesInScope: [SQLAutoCompletionTableFocus] = []
    ) -> SQLAutoCompletionQuery {
        SQLAutoCompletionQuery(
            token: token,
            prefix: prefix,
            pathComponents: [],
            replacementRange: NSRange(location: 0, length: token.count),
            precedingKeyword: precedingKeyword,
            precedingCharacter: token.isEmpty ? " " : token.last,
            focusTable: focusTable,
            tablesInScope: tablesInScope,
            clause: clause
        )
    }

    /// Flattens all suggestion titles from every section in the result.
    private func allTitles(from result: SQLAutoCompletionResult) -> [String] {
        result.sections.flatMap { $0.suggestions.map(\.title) }
    }

    // MARK: - Table Suggestions

    func testTableSuggestionsAfterFROM() throws {
        let engine = makeEngine()

        let text = "SELECT * FROM "
        let query = makeQuery(
            clause: .from,
            precedingKeyword: "FROM"
        )

        let result = engine.suggestions(for: query, text: text, caretLocation: text.count)
        let names = allTitles(from: result)

        XCTAssertTrue(names.contains("users"), "Should suggest 'users' table — got: \(names)")
        XCTAssertTrue(names.contains("orders"), "Should suggest 'orders' table — got: \(names)")
    }

    // MARK: - Column Suggestions

    func testColumnSuggestionsAfterSELECT() throws {
        let engine = makeEngine()

        // Use a non-empty token to bypass the manual trigger guard for selectList clause
        let text = "SELECT i FROM users"
        let caretLocation = 8 // right after "SELECT i"
        let focus = SQLAutoCompletionTableFocus(schema: "public", name: "users", alias: nil)
        let query = makeQuery(
            token: "i",
            prefix: "i",
            clause: .selectList,
            precedingKeyword: "SELECT",
            focusTable: focus,
            tablesInScope: [focus]
        )

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let names = allTitles(from: result)

        // Should suggest "id" column matching prefix "i"
        XCTAssertTrue(names.contains("id"), "Should suggest 'id' column from users table — got: \(names)")
    }

    // MARK: - JOIN Suggestions

    func testJoinSuggestions() throws {
        let engine = makeEngine()

        let text = "SELECT * FROM users JOIN "
        let usersRef = SQLAutoCompletionTableFocus(schema: "public", name: "users", alias: nil)
        let query = makeQuery(
            clause: .joinTarget,
            precedingKeyword: "JOIN",
            tablesInScope: [usersRef]
        )

        let result = engine.suggestions(for: query, text: text, caretLocation: text.count)
        let names = allTitles(from: result)

        XCTAssertTrue(names.contains("orders"), "Should suggest 'orders' for JOIN — got: \(names)")
    }
}
