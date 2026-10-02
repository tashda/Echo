import Foundation
import Testing
@testable import Echo

@Suite("Inspector list formatting")
@MainActor
struct InspectorListFormatTests {
    @Test func statementsCollapseToOneLine() {
        #expect(InspectorListFormat.oneLine("select *\nfrom  employees.employee;\n") == "select * from employees.employee;")
    }

    @Test func durationsReadLikeRunsTimer() {
        #expect(InspectorListFormat.duration(0.467) == "467 ms")
        #expect(InspectorListFormat.duration(65) == "1:05")
        #expect(InspectorListFormat.duration(5.656).hasSuffix(" s"))
    }

    @Test func dayTitlesNameTodayAndYesterday() {
        let now = Date()
        #expect(InspectorListFormat.dayTitle(now, now: now) == "Today")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        #expect(InspectorListFormat.dayTitle(yesterday, now: now) == "Yesterday")
    }

    @Test func coloringKeepsTheText() {
        let sql = "select 'it''s', 42 -- note\nfrom t"
        let attributed = InspectorSQLColoring.attributed(sql, tokens: SQLEditorTheme.fallback().palette.tokens)
        #expect(String(attributed.characters) == sql)
    }
}
