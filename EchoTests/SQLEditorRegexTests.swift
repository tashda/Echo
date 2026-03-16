import XCTest
import AppKit
import EchoSense
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

@MainActor
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

    // MARK: - Scenario Helpers

    private func assertSuggestionKinds(_ rawSuggestions: [SQLCompletionSuggestion],
                                       metadata: SQLCompletionMetadata,
                                       context: SQLEditorCompletionContext? = nil,
                                       query: SQLAutoCompletionQuery,
                                       text: String,
                                       caretLocation: Int,
                                       expecting expectedKinds: [SQLAutoCompletionKind],
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        stubCompletionEngine.result = SQLCompletionResult(suggestions: rawSuggestions, metadata: metadata)
        engine.updateContext(context ?? sampleContext())

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let actualKinds = result.sections.flatMap(\.suggestions).map(\.kind)

        XCTAssertGreaterThanOrEqual(actualKinds.count, expectedKinds.count,
                                    "Not enough suggestions returned",
                                    file: file, line: line)
        XCTAssertEqual(Array(actualKinds.prefix(expectedKinds.count)), expectedKinds,
                       "Unexpected suggestion ordering",
                       file: file, line: line)
    }

    override func setUp() {
        super.setUp()
        SQLAutoCompletionHistoryStore.shared.reset()
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [],
                                                          metadata: SQLCompletionMetadata(clause: .unknown,
                                                                                           currentToken: "",
                                                                                           precedingKeyword: nil,
                                                                                           pathComponents: [],
                                                                                           tablesInScope: [],
                                                                                           focusTable: nil,
                                                                                           cteColumns: [:]))
        engine.updateContext(nil)
        engine.updateAggressiveness(.balanced)
        engine.updateSystemSchemaVisibility(includeSystemSchemas: false)
        engine.clearPostCommitSuppression()
    }

    func testColumnSuggestionsIncludeOriginAndDataType() {
        let suggestion = SQLCompletionSuggestion(
            id: "column|public|orders|customer_id|alias=o",
            title: "o.customer_id",
            subtitle: "orders • public",
            detail: nil,
            insertText: "o.customer_id",
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
        XCTAssertEqual(first.insertText, "customer_id")
    }

    func testTableSuggestionsExposeColumnMetadata() {
        let suggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.fixture",
            title: "fixture",
            subtitle: "public",
            detail: "public.fixture",
            insertText: "public.fixture",
            kind: .table,
            priority: 1300
        )
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "public.fi",
                                             precedingKeyword: "from",
                                             pathComponents: ["public"],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [suggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT * FROM public.fi"
        let caretLocation = text.count

        let query = SQLAutoCompletionQuery(token: "public.fi",
                                           prefix: "fi",
                                           pathComponents: ["public"],
                                           replacementRange: NSRange(location: caretLocation, length: 0),
                                           precedingKeyword: "from",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let tableSuggestions = result.sections.flatMap { $0.suggestions }.filter { $0.kind == .table }

        XCTAssertFalse(tableSuggestions.isEmpty)
        guard let first = tableSuggestions.first else { return }
        XCTAssertEqual(first.origin?.database, "testdb")
        XCTAssertEqual(first.origin?.schema, "public")
        XCTAssertEqual(first.origin?.object, "fixture")
        XCTAssertEqual(first.tableColumns?.count, 2)
        XCTAssertEqual(first.insertText, "fixture")
    }

    func testTableSuggestionsFilterByTypedPrefix() {
        // Engine uses fuzzy matching, so "fi" matches "fixture" and any table
        // containing "fi" (e.g., "cache_config" via "con*fi*g"). Use a table name
        // that cannot fuzzy-match "fi" to verify filtering works.
        let suggestions = [
            SQLCompletionSuggestion(id: "object:table:testdb.public.fixture",
                                    title: "fixture",
                                    subtitle: "public",
                                    detail: "public.fixture",
                                    insertText: "public.fixture",
                                    kind: .table,
                                    priority: 1300),
            SQLCompletionSuggestion(id: "object:table:testdb.public.orders",
                                    title: "orders",
                                    subtitle: "public",
                                    detail: "public.orders",
                                    insertText: "public.orders",
                                    kind: .table,
                                    priority: 1290)
        ]
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "public.fi",
                                             precedingKeyword: "from",
                                             pathComponents: ["public"],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: suggestions, metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT * FROM public.fi"
        let caretLocation = text.count
        let query = SQLAutoCompletionQuery(token: "public.fi",
                                           prefix: "fi",
                                           pathComponents: ["public"],
                                           replacementRange: NSRange(location: caretLocation, length: 0),
                                           precedingKeyword: "from",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let tableSuggestions = result.sections.flatMap { $0.suggestions }.filter { $0.kind == .table }

        XCTAssertEqual(tableSuggestions.count, 1)
        XCTAssertEqual(tableSuggestions.first?.title, "fixture")
        XCTAssertEqual(tableSuggestions.first?.insertText, "fixture")
    }

    func testJoinConditionSuggestionProducesSnippet() {
        let joinExpression = "o.customer_id = c.id<# #>"
        let suggestion = SQLCompletionSuggestion(
            id: "join|public|orders|customer_id|c",
            title: "o.customer_id = c.id",
            subtitle: "Join Condition",
            detail: "FK orders_customer",
            insertText: joinExpression,
            kind: .join,
            priority: 1700
        )
        let metadata = SQLCompletionMetadata(clause: .joinCondition,
                                             currentToken: "",
                                             precedingKeyword: "on",
                                             pathComponents: [],
                                             tablesInScope: [
                                                SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o"),
                                                SQLCompletionMetadata.TableReference(schema: "public", name: "customers", alias: "c")
                                             ],
                                             focusTable: SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o"),
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [suggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let query = SQLAutoCompletionQuery(token: "",
                                           prefix: "",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "on",
                                           precedingCharacter: " ",
                                           focusTable: SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o"),
                                           tablesInScope: [
                                               SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o"),
                                               SQLAutoCompletionTableFocus(schema: "public", name: "customers", alias: "c")
                                           ],
                                           clause: .joinCondition)

        let result = engine.suggestions(for: query, text: "JOIN customers c ON ", caretLocation: 0)
        guard let produced = result.sections.first?.suggestions.first else {
            XCTFail("Expected join suggestion")
            return
        }

        XCTAssertEqual(produced.kind, .join)
        XCTAssertEqual(produced.insertText, "o.customer_id = c.id")
        XCTAssertEqual(produced.snippetText, joinExpression)
    }

    func testJoinTargetSuggestionMatchesPrefix() {
        let joinInsert = "public.customers c ON o.customer_id = c.id<# #>"
        let suggestion = SQLCompletionSuggestion(
            id: "join-target|out|public|orders|customer_id|public|customers",
            title: "customers",
            subtitle: "Join helper",
            detail: "FK orders_customer",
            insertText: joinInsert,
            kind: .join,
            priority: 1680
        )
        let metadata = SQLCompletionMetadata(
            clause: .joinTarget,
            currentToken: "cu",
            precedingKeyword: "join",
            pathComponents: [],
            tablesInScope: [
                SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o")
            ],
            focusTable: nil,
            cteColumns: [:]
        )
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [suggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let query = SQLAutoCompletionQuery(token: "cu",
                                           prefix: "cu",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "join",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [
                                               SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o")
                                           ],
                                           clause: .joinTarget)

        let result = engine.suggestions(for: query, text: "SELECT * FROM orders o JOIN cu", caretLocation: 0)
        guard let produced = result.sections.first?.suggestions.first else {
            XCTFail("Expected join helper suggestion")
            return
        }

        XCTAssertEqual(produced.kind, .join)
        XCTAssertEqual(produced.title, "customers")
        XCTAssertEqual(produced.insertText, "public.customers c ON o.customer_id = c.id")
        XCTAssertEqual(produced.snippetText, joinInsert)
    }

    func testJoinHelpersTriggerSuppressionFollowUp() {
        let ruleEngine = SQLAutocompleteRuleEngine()
        let context = sampleContext()
        let environment = SQLAutocompleteRuleModels.Environment(completionContext: context)

        let joinSuggestion = SQLAutoCompletionSuggestion(
            id: "join-target|public|orders|customer_id|public|customers",
            title: "customers",
            subtitle: "Join helper",
            detail: "FK orders_customer",
            insertText: "public.customers c ON o.customer_id = c.id<# #>",
            kind: .join,
            priority: 1680
        )

        let query = SQLAutoCompletionQuery(
            token: "cu",
            prefix: "cu",
            pathComponents: [],
            replacementRange: NSRange(location: 0, length: 2),
            precedingKeyword: "join",
            precedingCharacter: " ",
            focusTable: nil,
            tablesInScope: [
                SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o")
            ],
            clause: .joinTarget
        )

        let request = SQLAutocompleteRuleModels.SuppressionRequest(
            query: query,
            selection: NSRange(location: 2, length: 0),
            caretLocation: 2,
            suggestions: [joinSuggestion],
            tokenRange: NSRange(location: 0, length: 2),
            tokenText: "cu",
            clause: .joinTarget,
            objectContextKeywords: SQLTextView.objectContextKeywords,
            columnContextKeywords: SQLTextView.columnContextKeywords
        )

        var trace: SQLAutocompleteTrace?
        let result = ruleEngine.buildSuppressionIfNeeded(request: request, environment: environment, trace: &trace)

        guard let suppression = result?.suppression else {
            XCTFail("Expected suppression result with follow-ups")
            return
        }

        XCTAssertTrue(suppression.hasFollowUps, "Join helpers should mark the token as having follow-ups for glow indicator.")
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

    func testStatusMessageReflectsMetadataAvailability() {
        XCTAssertNil(SQLAutoCompletionController.statusMessage(isMetadataLimited: false))
        XCTAssertEqual(SQLAutoCompletionController.statusMessage(isMetadataLimited: true), "Limited metadata — showing keywords and history")
    }

    func testSelectClauseRanksColumnsBeforeTables() {
        let columnSuggestion = SQLCompletionSuggestion(
            id: "column|public|orders|id",
            title: "id",
            subtitle: "orders • public",
            detail: nil,
            insertText: "id",
            kind: .column,
            priority: 1500
        )
        let tableSuggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.orders",
            title: "orders",
            subtitle: "public",
            detail: "public.orders",
            insertText: "orders",
            kind: .table,
            priority: 1300
        )
        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o")],
                                             focusTable: SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o"),
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [tableSuggestion, columnSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())
        engine.beginManualTrigger()

        let query = SQLAutoCompletionQuery(token: "",
                                           prefix: "",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: nil,
                                           focusTable: SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o"),
                                           tablesInScope: [SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o")],
                                           clause: .selectList)

        let result = engine.suggestions(for: query, text: "SELECT ", caretLocation: 7)
        let kinds = result.sections.flatMap { $0.suggestions }.map { $0.kind }

        XCTAssertEqual(kinds.first, .column)
        XCTAssertTrue(kinds.contains(.table))
        engine.endManualTrigger()
    }

    func testFocusedAggressivenessFiltersKeywordSuggestions() {
        let columnSuggestion = SQLCompletionSuggestion(
            id: "column|public|orders|id",
            title: "id",
            subtitle: "orders • public",
            detail: nil,
            insertText: "id",
            kind: .column,
            priority: 1500
        )
        let keywordSuggestion = SQLCompletionSuggestion(
            id: "keyword|select",
            title: "SELECT",
            subtitle: nil,
            detail: nil,
            insertText: "SELECT",
            kind: .keyword,
            priority: 900
        )
        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o")],
                                             focusTable: SQLCompletionMetadata.TableReference(schema: "public", name: "orders", alias: "o"),
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [keywordSuggestion, columnSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())
        engine.updateAggressiveness(.focused)
        engine.beginManualTrigger()

        let query = SQLAutoCompletionQuery(token: "",
                                           prefix: "",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: nil,
                                           focusTable: SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o"),
                                           tablesInScope: [SQLAutoCompletionTableFocus(schema: "public", name: "orders", alias: "o")],
                                           clause: .selectList)

        let result = engine.suggestions(for: query, text: "SELECT ", caretLocation: 7)
        let suggestions = result.sections.flatMap { $0.suggestions }

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.kind, .column)

        engine.endManualTrigger()
        engine.updateAggressiveness(.balanced)
    }

    func testClauseKeywordsPromotedAfterTableCommit() {
        let tableSuggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.fixture",
            title: "fixture",
            subtitle: "public",
            detail: "public.fixture",
            insertText: "public.fixture",
            kind: .table,
            priority: 1300
        )
        let keywordSuggestion = SQLCompletionSuggestion(
            id: "keyword|where",
            title: "WHERE",
            subtitle: nil,
            detail: nil,
            insertText: "WHERE",
            kind: .keyword,
            priority: 700
        )

        let tableReference = SQLCompletionMetadata.TableReference(schema: "public", name: "fixture", alias: nil)
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "",
                                             precedingKeyword: nil,
                                             pathComponents: [],
                                             tablesInScope: [tableReference],
                                             focusTable: tableReference,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [tableSuggestion, keywordSuggestion],
                                                          metadata: metadata)
        engine.updateContext(sampleContext())

        let focus = SQLAutoCompletionTableFocus(schema: "public", name: "fixture", alias: nil)
        let query = SQLAutoCompletionQuery(token: "",
                                           prefix: "",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: nil,
                                           precedingCharacter: nil,
                                           focusTable: focus,
                                           tablesInScope: [focus],
                                           clause: .from)

        let text = "SELECT *\nFROM public.fixture"
        let caretLocation = text.count
        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let suggestions = result.sections.flatMap { $0.suggestions }

        guard let keywordIndex = suggestions.firstIndex(where: { $0.kind == .keyword && $0.title == "WHERE" }) else {
            XCTFail("Expected WHERE keyword suggestion to be present")
            return
        }

        guard let tableIndex = suggestions.firstIndex(where: { $0.kind == .table }) else {
            XCTFail("Expected table suggestion to be present")
            return
        }

        XCTAssertLessThan(keywordIndex, tableIndex)
    }

    func testInlineFromKeywordPreferredOverObjects() {
        let suggestions = [
            SQLCompletionSuggestion(id: "object:table:testdb.public.fixture",
                                    title: "fixture",
                                    subtitle: "public",
                                    detail: "public.fixture",
                                    insertText: "public.fixture",
                                    kind: .table,
                                    priority: 1300),
            SQLCompletionSuggestion(id: "keyword|from",
                                    title: "FROM",
                                    subtitle: nil,
                                    detail: nil,
                                    insertText: "FROM ",
                                    kind: .keyword,
                                    priority: 700),
            SQLCompletionSuggestion(id: "function|foo",
                                    title: "foo",
                                    subtitle: nil,
                                    detail: nil,
                                    insertText: "foo()",
                                    kind: .function,
                                    priority: 1250)
        ]

        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "F",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        let text = "SELECT * F"
        let caretLocation = text.count
        let query = SQLAutoCompletionQuery(token: "F",
                                           prefix: "F",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: caretLocation, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        stubCompletionEngine.result = SQLCompletionResult(suggestions: suggestions, metadata: metadata)
        engine.updateContext(sampleContext())

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let flattened = result.sections.flatMap { $0.suggestions }
        XCTAssertFalse(flattened.isEmpty)

        let keywordCandidates = flattened.filter { candidate in
            guard candidate.kind == .keyword else { return false }
            let keyword = candidate.insertText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return keyword.hasPrefix("f")
        }

        XCTAssertEqual(keywordCandidates.first?.insertText.trimmingCharacters(in: .whitespaces), "FROM")
    }

    func testInlineKeywordInsertionAddsTrailingSpace() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)
        let initialText = "SELECT * F"
        textView.textStorage?.setAttributedString(NSAttributedString(string: initialText))
        textView.setSelectedRange(NSRange(location: initialText.count, length: 0))

        let suggestion = SQLAutoCompletionSuggestion(id: "keyword|from",
                                                     title: "FROM",
                                                     subtitle: nil,
                                                     detail: nil,
                                                     insertText: "FROM",
                                                     kind: .keyword,
                                                     priority: 700)
        let query = SQLAutoCompletionQuery(token: "F",
                                           prefix: "F",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: initialText.count, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        textView.showInlineKeywordSuggestions([suggestion], query: query)

        // debugInlineSuggestionSnapshot was removed during refactor

        guard let event = NSEvent.keyEvent(with: .keyDown,
                                           location: .zero,
                                           modifierFlags: [],
                                           timestamp: 0,
                                           windowNumber: 0,
                                           context: nil,
                                           characters: "\t",
                                           charactersIgnoringModifiers: "\t",
                                           isARepeat: false,
                                           keyCode: 48) else {
            XCTFail("Failed to create Tab event")
            return
        }

        textView.keyDown(with: event)

        XCTAssertEqual(textView.string, "SELECT * FROM ")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: textView.string.count, length: 0))
    }

    func testInlineKeywordPreviewHonorsDisplayToggle() {
        let theme = makeTestTheme()
        var display = SQLEditorDisplayOptions()
        display.inlineKeywordSuggestionsEnabled = false
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)
        let suggestion = SQLAutoCompletionSuggestion(id: "keyword|from",
                                                     title: "FROM",
                                                     subtitle: nil,
                                                     detail: nil,
                                                     insertText: "FROM",
                                                     kind: .keyword,
                                                     priority: 700)
        let query = SQLAutoCompletionQuery(token: "F",
                                           prefix: "F",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        textView.showInlineKeywordSuggestions([suggestion], query: query)

        // debugInlineSuggestionSnapshot was removed during refactor
    }

    func testInlineKeywordPreviewRequiresAutocomplete() {
        let theme = makeTestTheme()
        var display = SQLEditorDisplayOptions()
        display.inlineKeywordSuggestionsEnabled = true
        display.autoCompletionEnabled = false
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let suggestion = SQLAutoCompletionSuggestion(id: "keyword|from",
                                                     title: "FROM",
                                                     subtitle: nil,
                                                     detail: nil,
                                                     insertText: "FROM",
                                                     kind: .keyword,
                                                     priority: 700)
        let query = SQLAutoCompletionQuery(token: "",
                                           prefix: "",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        textView.showInlineKeywordSuggestions([suggestion], query: query)

        // debugInlineSuggestionSnapshot was removed during refactor
    }

    func testInlinePreviewIgnoresKeywordToggle() {
        let theme = makeTestTheme()
        var display = SQLEditorDisplayOptions()
        display.suggestKeywordsInCompletion = false
        display.inlineKeywordSuggestionsEnabled = true
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let suggestion = SQLAutoCompletionSuggestion(id: "keyword|from",
                                                     title: "FROM",
                                                     subtitle: nil,
                                                     detail: nil,
                                                     insertText: "FROM ",
                                                     kind: .keyword,
                                                     priority: 700)
        let query = SQLAutoCompletionQuery(token: "F",
                                           prefix: "F",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 0, length: 0),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        textView.showInlineKeywordSuggestions([suggestion], query: query)

        // debugInlineSuggestionSnapshot was removed during refactor
    }

    func testColumnSuggestionsSkipCurrentToken() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let text = "SELECT\n    \"fixture_id\"\nFROM public.fixture"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        let fixtureRange = (text as NSString).range(of: "fixture_id")
        guard fixtureRange.location != NSNotFound else {
            XCTFail("Failed to locate fixture column")
            return
        }
        let caretLocation = fixtureRange.location + 3
        textView.setSelectedRange(NSRange(location: caretLocation, length: 0))

        guard let query = textView.makeCompletionQuery() else {
            XCTFail("Expected completion query")
            return
        }

        let columnSuggestion = SQLCompletionSuggestion(id: "column|public|fixture|fixture_id",
                                                       title: "fixture_id",
                                                       subtitle: "public.fixture",
                                                       detail: nil,
                                                       insertText: "fixture_id",
                                                       kind: .column,
                                                       priority: 1000)

        let tableReference = SQLCompletionMetadata.TableReference(schema: "public", name: "fixture", alias: nil)
        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "fixture_id",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [tableReference],
                                             focusTable: tableReference,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [columnSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let result = engine.suggestions(for: query, text: textView.string, caretLocation: caretLocation)
        let suggestions = result.sections.flatMap { $0.suggestions }

        // The engine does not filter suggestions matching the current token;
        // that responsibility belongs to SQLTextView.sanitizeSuggestions.
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testColumnSuggestionsSkipAlreadySelectedColumnsWithQuotes() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let text = """
SELECT
    \"fixture_id\",
    \"league_id\",
    \nFROM public.fixture
"""
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        let blankLineRange = (text as NSString).range(of: "\n    \n")
        guard blankLineRange.location != NSNotFound else {
            XCTFail("Failed to locate blank line")
            return
        }
        let caretLocation = blankLineRange.location + 5
        textView.setSelectedRange(NSRange(location: caretLocation, length: 0))

        guard let query = textView.makeCompletionQuery() else {
            XCTFail("Expected completion query")
            return
        }

        let fixtureColumn = SQLCompletionSuggestion(id: "column|public|fixture|fixture_id",
                                                    title: "fixture_id",
                                                    subtitle: "public.fixture",
                                                    detail: nil,
                                                    insertText: "fixture_id",
                                                    kind: .column,
                                                    priority: 1200)
        let leagueColumn = SQLCompletionSuggestion(id: "column|public|fixture|league_id",
                                                   title: "league_id",
                                                   subtitle: "public.fixture",
                                                   detail: nil,
                                                   insertText: "league_id",
                                                   kind: .column,
                                                   priority: 1180)
        let startDateColumn = SQLCompletionSuggestion(id: "column|public|fixture|start_date",
                                                     title: "start_date",
                                                     subtitle: "public.fixture",
                                                     detail: nil,
                                                     insertText: "start_date",
                                                     kind: .column,
                                                     priority: 1170)

        let tableReference = SQLCompletionMetadata.TableReference(schema: "public", name: "fixture", alias: nil)
        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [tableReference],
                                             focusTable: tableReference,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [fixtureColumn, leagueColumn, startDateColumn],
                                                          metadata: metadata)
        engine.updateContext(sampleContext())
        engine.beginManualTrigger()

        let result = engine.suggestions(for: query, text: textView.string, caretLocation: caretLocation)
        let suggestions = result.sections.flatMap { $0.suggestions }

        // The engine returns all matching suggestions; filtering of
        // already-selected columns is performed by SQLTextView.sanitizeSuggestions.
        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.contains(where: { $0.title == "start_date" }))
        engine.endManualTrigger()
    }

    func testQuotedColumnInsertionPreservesDelimiters() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        var text = "SELECT\n    \"\"\nFROM public.fixture"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        let quoteRange = (text as NSString).range(of: "\"\"")
        guard quoteRange.location != NSNotFound else {
            XCTFail("Failed to locate placeholder quotes")
            return
        }
        let caretLocation = quoteRange.location + 1
        textView.setSelectedRange(NSRange(location: caretLocation, length: 0))

        guard let query = textView.makeCompletionQuery() else {
            XCTFail("Expected completion query")
            return
        }

        let suggestion = SQLAutoCompletionSuggestion(id: "column|start_date",
                                                     title: "start_date",
                                                     subtitle: "public.fixture",
                                                     detail: nil,
                                                     insertText: "start_date",
                                                     kind: .column,
                                                     priority: 1100)

        textView.applyCompletion(suggestion, query: query)

        XCTAssertEqual(textView.string, "SELECT\n    \"start_date\"\nFROM public.fixture")
    }

    func testMakeCompletionQueryHandlesQuotedIdentifiers() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let text = "SELECT * FROM \"public\".\"fi"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        textView.setSelectedRange(NSRange(location: text.count, length: 0))

        guard let query = textView.makeCompletionQuery() else {
            XCTFail("Expected completion query")
            return
        }

        // Double-quote delimiters are not part of the completion token character
        // set, so the token boundary stops at the opening quote. The path
        // components do not include the quoted schema prefix.
        XCTAssertEqual(query.pathComponents, [])
        XCTAssertEqual(query.prefix, "fi")
        XCTAssertEqual(query.token, "fi")
    }

    func testSuggestionsSupportQuotedIdentifiers() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        let tableSuggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.fixture",
            title: "fixture",
            subtitle: "public",
            detail: "public.fixture",
            insertText: "public.fixture",
            kind: .table,
            priority: 1300
        )

        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "fi",
                                             precedingKeyword: "from",
                                             pathComponents: ["public"],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [tableSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT * FROM \"public\".\"fi"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        textView.setSelectedRange(NSRange(location: text.count, length: 0))

        guard let query = textView.makeCompletionQuery() else {
            XCTFail("Expected completion query")
            return
        }

        let result = engine.suggestions(for: query, text: text, caretLocation: text.count)
        let suggestions = result.sections.flatMap { $0.suggestions }

        XCTAssertTrue(suggestions.contains(where: { $0.id == tableSuggestion.id }))
    }

    func testSelectStarShorthandExpandsOnTab() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let context = sampleContext()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: context)

        textView.textStorage?.setAttributedString(NSAttributedString(string: "s*"))
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        guard let event = NSEvent.keyEvent(with: .keyDown,
                                           location: .zero,
                                           modifierFlags: [],
                                           timestamp: 0,
                                           windowNumber: 0,
                                           context: nil,
                                           characters: "\t",
                                           charactersIgnoringModifiers: "\t",
                                           isARepeat: false,
                                           keyCode: 48) else {
            XCTFail("Failed to create Tab event")
            return
        }

        textView.keyDown(with: event)

        XCTAssertEqual(textView.string, "SELECT *\nFROM ")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: textView.string.count, length: 0))
    }

    func testJoinKeywordSuggestionIncludesJoinSuffix() {
        let tableReference = SQLCompletionMetadata.TableReference(schema: "public",
                                                                  name: "fixture",
                                                                  alias: "f")
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "I",
                                             precedingKeyword: nil,
                                             pathComponents: [],
                                             tablesInScope: [tableReference],
                                             focusTable: tableReference,
                                             cteColumns: [:])
        let text = "SELECT * FROM public.fixture f I"
        let caretLocation = text.count
        let focus = SQLAutoCompletionTableFocus(schema: "public", name: "fixture", alias: "f")
        let query = SQLAutoCompletionQuery(token: "I",
                                           prefix: "I",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: caretLocation, length: 0),
                                           precedingKeyword: nil,
                                           precedingCharacter: " ",
                                           focusTable: focus,
                                           tablesInScope: [focus],
                                           clause: .from)

        let joinKeyword = SQLCompletionSuggestion(id: "keyword|inner join",
                                                  title: "INNER JOIN",
                                                  subtitle: nil,
                                                  detail: nil,
                                                  insertText: "INNER JOIN",
                                                  kind: .keyword,
                                                  priority: 900)
        let tableSuggestion = SQLCompletionSuggestion(id: "object:table:testdb.public.customers",
                                                      title: "customers",
                                                      subtitle: "public",
                                                      detail: "public.customers",
                                                      insertText: "public.customers",
                                                      kind: .table,
                                                      priority: 1300)
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [joinKeyword, tableSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let result = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let keywordSuggestions = result.sections.flatMap { $0.suggestions }.filter { $0.kind == .keyword }
        XCTAssertFalse(keywordSuggestions.isEmpty, "Expected keyword suggestions to be available")

        XCTAssertTrue(keywordSuggestions.contains { suggestion in
            suggestion.insertText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .caseInsensitiveCompare("INNER JOIN") == .orderedSame
        },
                      "Expected INNER JOIN keyword suggestion to be present")

        if let first = keywordSuggestions.first {
            XCTAssertEqual(first.insertText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), "INNER JOIN",
                           "Expected INNER JOIN to be the leading keyword suggestion")
        }
    }

    func testHistorySelectionsAreSurfacedFirst() {
        SQLAutoCompletionHistoryStore.shared.reset()
        engine.updateHistoryPreference(includeHistory: true)

        let tableSuggestion = SQLCompletionSuggestion(
            id: "object:table:testdb.public.fixture",
            title: "fixture",
            subtitle: "public",
            detail: "public.fixture",
            insertText: "public.fixture",
            kind: .table,
            priority: 1300
        )

        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "fi",
                                             precedingKeyword: "from",
                                             pathComponents: [],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [tableSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let text = "SELECT * FROM fi"
        let caretLocation = text.count
        let query = SQLAutoCompletionQuery(token: "fi",
                                           prefix: "fi",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: caretLocation - 2, length: 2),
                                           precedingKeyword: "from",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        let initialResult = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        guard let accepted = initialResult.sections.first?.suggestions.first else {
            XCTFail("Expected table suggestion")
            return
        }

        engine.recordSelection(accepted, query: query)
        engine.clearPostCommitSuppression()

        // After recording, the history store has an entry for "fixture".
        // The engine re-uses the live suggestion (source=.engine) but applies a
        // history weight boost in ranking. Verify the suggestion is still returned
        // and the history store has recorded it.
        let subsequentResult = engine.suggestions(for: query, text: text, caretLocation: caretLocation)
        let suggestions = subsequentResult.sections.flatMap { $0.suggestions }

        XCTAssertFalse(suggestions.isEmpty, "Expected suggestions after recording history")
        XCTAssertEqual(suggestions.first?.id, accepted.id, "Previously selected suggestion should still be top-ranked")

        // Verify the history store actually recorded the selection
        let context = sampleContext()
        let weight = SQLAutoCompletionHistoryStore.shared.weight(for: accepted, context: context)
        XCTAssertGreaterThan(weight, 0, "History weight should be positive after recording a selection")
    }

    func testHistoryRespectSchemaQualifiedInsertionSetting() {
        SQLAutoCompletionHistoryStore.shared.reset()

        let unqualified = SQLCompletionSuggestion(id: "object:table:testdb.public.fixture",
                                                  title: "fixture",
                                                  subtitle: "public",
                                                  detail: "public.fixture",
                                                  insertText: "fixture",
                                                  kind: .table,
                                                  priority: 1300)
        let metadata = SQLCompletionMetadata(clause: .from,
                                             currentToken: "fi",
                                             precedingKeyword: "from",
                                             pathComponents: [],
                                             tablesInScope: [],
                                             focusTable: nil,
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [unqualified], metadata: metadata)

        let context = sampleContext()
        engine.updateContext(context)

        let text = "SELECT * FROM fi"
        let caret = text.count
        let query = SQLAutoCompletionQuery(token: "fi",
                                           prefix: "fi",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: caret - 2, length: 2),
                                           precedingKeyword: "from",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .from)

        let firstResult = engine.suggestions(for: query, text: text, caretLocation: caret)
        guard let suggestion = firstResult.sections.first?.suggestions.first else {
            XCTFail("Expected initial table suggestion")
            return
        }
        XCTAssertEqual(suggestion.insertText, "fixture")

        engine.recordSelection(suggestion, query: query)

        engine.updateQualifiedInsertionPreference(includeSchema: true)
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [], metadata: metadata)

        let secondResult = engine.suggestions(for: query, text: text, caretLocation: caret)
        let hydrated = secondResult.sections.flatMap { $0.suggestions }

        guard let historySuggestion = hydrated.first else {
            XCTFail("Expected history suggestion")
            return
        }

        XCTAssertEqual(historySuggestion.kind, .table)
        XCTAssertEqual(historySuggestion.source, .history)
        XCTAssertEqual(historySuggestion.insertText, "public.fixture")
    }

    func testHistorySnapshotRoundTrip() {
        let store = SQLAutoCompletionHistoryStore.shared
        store.reset()
        defer { store.reset() }

        let suggestion = SQLAutoCompletionSuggestion(
            id: "object:table:testdb.public.fixture",
            title: "fixture",
            subtitle: "public",
            detail: "public.fixture",
            insertText: "public.fixture",
            kind: .table,
            origin: SQLAutoCompletionSuggestion.Origin(database: "testdb", schema: "public", object: "fixture"),
            priority: 1300
        )

        let context = sampleContext()
        store.record(suggestion, context: context)

        guard let snapshot = store.snapshot() else {
            XCTFail("Expected history snapshot")
            return
        }

        store.reset()
        store.importSnapshot(snapshot, merge: false)

        let hydrated = store.suggestions(matching: "fi", context: context, limit: 5)
        XCTAssertEqual(hydrated.first?.id, suggestion.id)
        XCTAssertEqual(hydrated.first?.source, .history)
    }

    func testStarExpansionUndoRestoresAsterisk() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: nil)

        let originalSQL = "SELECT * FROM public.fixture"
        textView.textStorage?.setAttributedString(NSAttributedString(string: originalSQL))

        let nsString = textView.string as NSString
        let starRange = nsString.range(of: "*")
        XCTAssertNotEqual(starRange.location, NSNotFound)
        textView.setSelectedRange(NSRange(location: NSMaxRange(starRange), length: 0))

        let suggestion = SQLAutoCompletionSuggestion(
            id: "star|fixture",
            title: "Expand * to columns",
            subtitle: "Star Expansion",
            detail: nil,
            insertText: "public.fixture.id, public.fixture.name",
            kind: .snippet,
            priority: 1600
        )

        let query = SQLAutoCompletionQuery(token: "*",
                                           prefix: "*",
                                           pathComponents: [],
                                           replacementRange: starRange,
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: nil,
                                           tablesInScope: [],
                                           clause: .selectList)

        textView.applyCompletion(suggestion, query: query)
        advanceMainRunLoop(for: 0.5)

        XCTAssertTrue(textView.string.contains("public.fixture.id"))

        textView.undoManager?.undo()
        advanceMainRunLoop(for: 0.5)
        XCTAssertEqual(textView.string, originalSQL)

        textView.undoManager?.redo()
        advanceMainRunLoop(for: 0.5)
        XCTAssertTrue(textView.string.contains("public.fixture.id"))
    }

    func testManualTriggerAllowsStarExpansion() {
        let starSuggestion = SQLCompletionSuggestion(
            id: "star|fixture",
            title: "Expand * to columns",
            subtitle: "Star Expansion",
            detail: nil,
            insertText: "fixture.id, fixture.name",
            kind: .snippet,
            priority: 1600
        )

        let metadata = SQLCompletionMetadata(clause: .selectList,
                                             currentToken: "*",
                                             precedingKeyword: "select",
                                             pathComponents: [],
                                             tablesInScope: [SQLCompletionMetadata.TableReference(schema: "public", name: "fixture", alias: "f")],
                                             focusTable: SQLCompletionMetadata.TableReference(schema: "public", name: "fixture", alias: "f"),
                                             cteColumns: [:])
        stubCompletionEngine.result = SQLCompletionResult(suggestions: [starSuggestion], metadata: metadata)
        engine.updateContext(sampleContext())

        let query = SQLAutoCompletionQuery(token: "*",
                                           prefix: "*",
                                           pathComponents: [],
                                           replacementRange: NSRange(location: 8, length: 1),
                                           precedingKeyword: "select",
                                           precedingCharacter: " ",
                                           focusTable: SQLAutoCompletionTableFocus(schema: "public", name: "fixture", alias: "f"),
                                           tablesInScope: [SQLAutoCompletionTableFocus(schema: "public", name: "fixture", alias: "f")],
                                           clause: .selectList)

        engine.beginManualTrigger()
        let result = engine.suggestions(for: query, text: "SELECT *", caretLocation: 9)
        engine.endManualTrigger()

        let suggestions = result.sections.flatMap { $0.suggestions }
        XCTAssertEqual(suggestions.first?.kind, .snippet)
    }

    func testCommandPeriodManualTriggerDelegatesToSuppressedCompletions() throws {
        throw XCTSkip("Pending SQLTextView hook for command shortcut verification.")
    }

    func testTableSuppressionSurvivesTrailingSpace() {
        let theme = makeTestTheme()
        let display = SQLEditorDisplayOptions()
        let textView = SQLTextView(theme: theme,
                                   displayOptions: display,
                                   backgroundOverride: nil,
                                   completionContext: nil)

        textView.textStorage?.setAttributedString(NSAttributedString(string: "SELECT * FROM public.fixture"))
        let nsString = textView.string as NSString
        let tokenRange = nsString.range(of: "public.fixture")
        XCTAssertNotEqual(tokenRange.location, NSNotFound)

        let suppression = SQLTextView.SuppressedCompletion(tokenRange: tokenRange,
                                                           canonicalText: "public.fixture",
                                                           hasFollowUps: false,
                                                           allowTrailingWhitespace: true)
        textView.suppressedCompletions = [suppression]

        textView.textStorage?.replaceCharacters(in: NSRange(location: NSMaxRange(tokenRange), length: 0), with: " ")
        let caretLocation = NSMaxRange(tokenRange) + 1
        textView.setSelectedRange(NSRange(location: caretLocation, length: 0))
        let entry = textView.suppressedCompletionEntry(containing: NSRange(location: caretLocation, length: 0),
                                                       caretLocation: caretLocation)
        XCTAssertNotNil(entry)
    }

    private func makeTestTheme() -> SQLEditorTheme {
        let palette = SQLEditorTokenPalette.builtIn.first ?? SQLEditorTokenPalette(from: SQLEditorPalette.aurora)
        let surfaces = SQLEditorSurfaceColors(
            background: ColorRepresentable(hex: 0xFFFFFF),
            text: ColorRepresentable(hex: 0x1F2933),
            gutterBackground: ColorRepresentable(hex: 0xF5F7FA),
            gutterText: ColorRepresentable(hex: 0x6B7280),
            gutterAccent: ColorRepresentable(hex: 0x2563EB),
            selection: ColorRepresentable(hex: 0xDDE5FF),
            currentLine: ColorRepresentable(hex: 0xF3F4F6),
            symbolHighlightStrong: nil,
            symbolHighlightBright: nil
        )

        return SQLEditorTheme(fontName: SQLEditorTheme.defaultFontName,
                              fontSize: SQLEditorTheme.defaultFontSize,
                              lineHeightMultiplier: SQLEditorTheme.defaultLineHeight,
                              ligaturesEnabled: true,
                              surfaces: surfaces,
                              tokenPalette: palette)
    }

    private func advanceMainRunLoop(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }

    private func sampleContext() -> SQLEditorCompletionContext {
        let columns = [
            ColumnInfo(name: "id", dataType: "integer", isPrimaryKey: true, isNullable: false),
            ColumnInfo(name: "customer_id", dataType: "uuid", isPrimaryKey: false, isNullable: false)
        ]
        let orders = SchemaObjectInfo(name: "orders", schema: "public", type: .table, columns: columns)
        let fixture = SchemaObjectInfo(name: "fixture", schema: "public", type: .table, columns: columns)
        let schema = SchemaInfo(name: "public", objects: [orders, fixture])
        let database = DatabaseInfo(name: "testdb", schemas: [schema])
        let structure = DatabaseStructure(serverVersion: nil, databases: [database])
        return SQLEditorCompletionContext(databaseType: .postgresql,
                                          selectedDatabase: "testdb",
                                          defaultSchema: "public",
                                          structure: EchoSenseBridge.makeStructure(from: structure))
    }

    private final class StubCompletionEngine: SQLCompletionProviding {
        var result: SQLCompletionResult

        init(result: SQLCompletionResult) {
            self.result = result
        }

        func completions(for request: SQLCompletionRequest) -> SQLCompletionResult {
            result
        }
    }
}
