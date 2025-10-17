import XCTest
@testable import Echo

final class SQLEditorRegexTests: XCTestCase {
    func testDoubleQuotedStringPatternCompiles() {
        XCTAssertNoThrow(try NSRegularExpression(pattern: SQLEditorRegex.doubleQuotedStringPattern))
    }

    func testMatchesSimpleIdentifiers() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"customer\" FROM \"orders\";"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 2)
        let tokens = matches.compactMap { Range($0.range, in: sql).map { String(sql[$0]) } }
        XCTAssertEqual(tokens, ["\"customer\"", "\"orders\""])
    }

    func testAllowsEscapedDoubleQuotes() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"He said \"\"Hello\"\"\" AS quote;"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 1)
        if let matchRange = matches.first, let range = Range(matchRange.range, in: sql) {
            XCTAssertEqual(sql[range], "\"He said \"\"Hello\"\"\"")
        } else {
            XCTFail("Expected escaped quote string to match")
        }
    }

    func testDoesNotMatchUnterminatedString() {
        let regex = SQLEditorRegex.doubleQuotedStringRegex
        let sql = "SELECT \"unterminated FROM table;"
        let matches = regex.matches(
            in: sql,
            range: NSRange(sql.startIndex..<sql.endIndex, in: sql)
        )
        XCTAssertEqual(matches.count, 0)
    }
}

final class SQLAutoCompletionEngineTests: XCTestCase {
    private let stubCompletionEngine = StubCompletionEngine(result: SQLCompletionResult(suggestions: [],
                                                                                        metadata: SQLCompletionMetadata(clause: .unknown,
                                                                                                                         currentToken: "",
                                                                                                                         precedingKeyword: nil,
                                                                                                                         pathComponents: [],
                                                                                                                         tablesInScope: [],
                                                                                                                         focusTable: nil,
                                                                                                                         cteColumns: [:])))
    private lazy var engine = SQLAutoCompletionEngine(completionEngine: stubCompletionEngine)

    func testColumnSuggestionsIncludeOriginAndDataType() {
        let suggestion = SQLCompletionSuggestion(
            id: "column|public|orders|customer_id",
            title: "customer_id",
            subtitle: "orders • public",
            detail: nil,
            insertText: "customer_id",
            kind: .column,
            priority: 1500
        )
        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "",
                                             precedingKeyword: nil,
                                             pathComponents: [],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [suggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT o.\nFROM public.orders o"
        let caretLocation = (text as NSString).range(of: "SELECT o.").length

        let focus = SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o")
        let query = SQLAutoCompletionQuery(
            token: "o.",
            prefix: "",
            pathComponents: ["o"],
            replacementRange: NSRange(location: caretLocation, length: 0),
            precedingKeyword: "select",
            precedingCharacter: nil,
            focusTable: focus,
            tablesInScope: [focus],
            clause: .selectList
        )

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let columnSuggestions = result.sections.flatMap { $0.suggestions }.filter { $0.kind == .column }

        XCTAssertFalse(columnSuggestions.isEmpty)
        guard let first = columnSuggestions.first else { return }
        XCTAssertEqual(first.origin?.database, "testdb")
        XCTAssertEqual(first.origin?.schema, "public")
        XCTAssertEqual(first.origin?.object, "orders")
        XCTAssertEqual(first.origin?.column, "customer_id")
        XCTAssertEqual(first.dataType, "uuid")
    }

    func testTableSuggestionsExposeColumnMetadata() {
        let suggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.orders",
            title: "orders",
            subtitle: "public",
            detail: "public.orders",
            insertText: "orders",
            kind: .table,
            priority: 1300
        )
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "",
                                             precedingKeyword: nil,
                                             pathComponents: [],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [suggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT * FROM "
        let caretLocation = text.count

        let query = SQLAutoCompletionQuery(
            token: "",
            prefix: "",
            pathComponents: [],
            replacementRange: NSRange(location: caretLocation, length: 0),
            precedingKeyword: "from",
            precedingCharacter: " ",
            focusTable: nil,
            tablesInScope: [],
            clause: .from
        )

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let tableSuggestions = result.sections.flatMap { $0.suggestions }.filter { $0.kind == .table }

        XCTAssertFalse(tableSuggestions.isEmpty)
        guard let first = tableSuggestions.first else { return }
        XCTAssertEqual(first.origin?.database, "testdb")
        XCTAssertEqual(first.origin?.schema, "public")
        XCTAssertEqual(first.origin?.object, "orders")
        XCTAssertEqual(first.tableColumns?.count, 2)
    }

    func testMetadataLimitedFlagReflectsStructureAvailability() {
        let limitedContext = SQLEditorCompletionContext(databaseType: .postgresql,
                                                        selectedDatabase: nil,
                                                        defaultSchema: nil,
                                                        structure: nil)
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [],
                                                          metadata: SQLCompletionMetadata(clause: .unknown,
                                                                                           currentToken: "",
                                                                                           precedingKeyword: nil,
                                                                                           pathComponents: [],
                                                                                           tablesInScope: [],
                                                                                           focusTable: nil,
                                                                                           cteColumns: [:]))
        engine.updateContext(limitedContext)
        XCTAssertTrue(engine.isMetadataLimited)

        engine.updateContext(sampleContext())
        XCTAssertFalse(engine.isMetadataLimited)
    }

    private func sampleContext() -> SQLEditorCompletionContext {
        let columns = [
            ColumnInfo(name: "id", dataType: "integer", isPrimaryKey: true, isNullable: false),
            ColumnInfo(name: "customer_id", dataType: "uuid", isPrimaryKey: false, isNullable: false)
        ]
        let orders = SchemaObjectInfo(name: "orders", schema: "public", type: .table, columns: columns)
        let schema = SchemaInfo(name: "public", objects: [orders])
        let database = DatabaseInfo(name: "testdb", schemas: [schema])
        let structure = DatabaseStructure(serverVersion: nil, databases: [database])
        return SQLEditorCompletionContext(databaseType: .postgresql,
                                          selectedDatabase: "testdb",
                                          defaultSchema: "public",
                                          structure: structure)
    }

    private final class StubCompletionEngine: SQLCompletionEngineProtocol {
        var result: SQLCompletionResult

        init(result: SQLCompletionResult) {
            self.result = result
        }

        func completions(for request: SQLCompletionRequest) -> SQLCompletionResult {
            result
        }
    }
}
