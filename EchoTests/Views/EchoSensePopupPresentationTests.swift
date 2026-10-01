import Foundation
import Testing
import EchoSense
@testable import Echo

@MainActor
@Suite("EchoSense popup presentation")
struct EchoSensePopupPresentationTests {
    private func column(_ title: String, facts: SQLAutoCompletionSuggestion.ColumnFacts? = nil) -> SQLAutoCompletionSuggestion {
        SQLAutoCompletionSuggestion(title: title, insertText: title, kind: .column,
                                    origin: .init(database: "AdventureWorks2022", schema: "Sales", object: "SalesOrderHeader", column: "CustomerID"),
                                    dataType: "int", columnFacts: facts)
    }

    @Test func qualifiedColumnsSplitIntoNameAndQualifier() {
        let split = column("soh.CustomerID").nameAndQualifier
        #expect(split.name == "CustomerID")
        #expect(split.qualifier == "soh")
        #expect(column("CustomerID").nameAndQualifier.qualifier == nil)
    }

    @Test func tablesKeepDottedTitlesWhole() {
        let table = SQLAutoCompletionSuggestion(title: "Sales.Customer", insertText: "Sales.Customer", kind: .table)
        #expect(table.nameAndQualifier.name == "Sales.Customer")
        #expect(table.nameAndQualifier.qualifier == nil)
    }

    @Test func columnsShowTheirTypeOnTheRight() {
        #expect(column("CustomerID").trailingText == "int")
        #expect(SQLAutoCompletionSuggestion(title: "CASE", insertText: "CASE", kind: .keyword).trailingText == nil)
    }

    @Test func footerDescribesColumnFacts() {
        let facts = SQLAutoCompletionSuggestion.ColumnFacts(isNullable: false, isPrimaryKey: false, foreignKeyTarget: "Sales.Customer.CustomerID")
        #expect(column("CustomerID", facts: facts).footerDetail == "Sales.SalesOrderHeader · not null · references Sales.Customer.CustomerID")
        let key = SQLAutoCompletionSuggestion.ColumnFacts(isNullable: false, isPrimaryKey: true)
        #expect(column("SalesOrderID", facts: key).footerDetail == "Sales.SalesOrderHeader · not null · primary key")
    }

    @Test func everyKindHasABadge() {
        let kinds: [SQLAutoCompletionKind] = [.schema, .table, .view, .materializedView, .column, .function, .keyword, .snippet, .parameter, .join, .database]
        for kind in kinds {
            #expect(!SQLAutoCompletionSuggestion(title: "x", insertText: "x", kind: kind).badgeText.isEmpty)
        }
    }

    @Test func contiguousMatchesHighlightOneRange() {
        let text = "CustomerID"
        let ranges = AutoCompletionMatchText.matchRanges(of: "cu", in: text)
        #expect(ranges.count == 1)
        #expect(ranges.first.map { String(text[$0]) } == "Cu")
    }

    @Test func fuzzyMatchesHighlightEachLetter() {
        let text = "CustomerID"
        let ranges = AutoCompletionMatchText.matchRanges(of: "cid", in: text)
        #expect(ranges.map { String(text[$0]) } == ["C", "I", "D"])
        #expect(AutoCompletionMatchText.matchRanges(of: "xyz", in: text).isEmpty)
    }

    @Test func popupCornerFollowsCardCornersWithinLimits() {
        #expect(LayoutTokens.EchoSense.cornerRadius(cardCornerRadius: 12) == 12)
        #expect(LayoutTokens.EchoSense.cornerRadius(cardCornerRadius: 26) == LayoutTokens.EchoSense.maxCornerRadius)
        #expect(LayoutTokens.EchoSense.rowCornerRadius(cardCornerRadius: 12) == 12 - LayoutTokens.EchoSense.padding)
    }
}
