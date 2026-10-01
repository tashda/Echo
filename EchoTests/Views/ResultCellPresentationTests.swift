import AppKit
import Testing
@testable import Echo

@Suite("Result cell presentation")
struct ResultCellPresentationTests {
    @Test func numbersAndDatesAlignRight() {
        #expect(ResultCellPresentation.alignment(for: .numeric) == .right)
        #expect(ResultCellPresentation.alignment(for: .temporal) == .right)
        #expect(ResultCellPresentation.alignment(for: .text) == .left)
        #expect(ResultCellPresentation.alignment(for: .boolean) == .center)
    }

    @Test func booleansBecomeSymbols() {
        #expect(ResultCellPresentation.displayText("true", kind: .boolean) == "✓")
        #expect(ResultCellPresentation.displayText("0", kind: .boolean) == "✗")
        #expect(ResultCellPresentation.displayText("maybe", kind: .boolean) == "maybe")
        #expect(ResultCellPresentation.displayText("true", kind: .text) == "true")
    }

    @Test func nullStaysText() {
        #expect(ResultCellPresentation.displayText(nil, kind: .null) == "NULL")
    }
}
